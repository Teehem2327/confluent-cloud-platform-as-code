import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

from monitoring import confluent_dynatrace_multi as collector


class TestCollector(unittest.TestCase):

    def test_checkpoint_persistence(self):
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "checkpoints.json"

            with patch.object(collector, "CHECKPOINT_FILE", checkpoint):
                collector.save_checkpoints({
                    "dev": "2026-11-04T18:31:00Z"
                })

                result = collector.load_checkpoints()

                self.assertEqual(
                    result["dev"],
                    "2026-11-04T18:31:00Z"
                )

    def test_missing_checkpoint(self):
        with tempfile.TemporaryDirectory() as directory:
            checkpoint = Path(directory) / "missing.json"

            with patch.object(collector, "CHECKPOINT_FILE", checkpoint):
                self.assertEqual(collector.load_checkpoints(), {})

    @patch.object(collector, "time")
    @patch.object(collector, "urlopen")
    def test_retry_on_server_error(self, mock_urlopen, mock_time):
        error = HTTPError(
            "https://example.com",
            503,
            "Service Unavailable",
            {},
            None
        )

        response = unittest.mock.MagicMock()
        response.__enter__.return_value.status = 200
        response.__enter__.return_value.read.return_value = b'{"data": []}'

        mock_urlopen.side_effect = [error, response]

        status, _ = collector.post(
            "https://example.com",
            b"{}",
            {"Content-Type": "application/json"}
        )

        self.assertEqual(status, 200)
        self.assertEqual(mock_urlopen.call_count, 2)
        mock_time.sleep.assert_called_once()

    @patch.object(collector, "urlopen")
    def test_no_retry_on_authentication_error(self, mock_urlopen):
        mock_urlopen.side_effect = HTTPError(
            "https://example.com",
            401,
            "Unauthorized",
            {},
            None
        )

        with self.assertRaises(RuntimeError):
            collector.post(
                "https://example.com",
                b"{}",
                {}
            )

        self.assertEqual(mock_urlopen.call_count, 1)

    @patch.object(collector, "post")
    def test_dynatrace_success(self, mock_post):
        mock_post.return_value = (
            202,
            json.dumps({
                "linesOk": 1,
                "linesInvalid": 0
            })
        )

        env = {
            "name": "dev",
            "cluster_name": "kafka-dev"
        }

        samples = [{
            "timestamp": "2026-11-04T18:31:00Z",
            "value": 100
        }]

        credentials = {
            "dynatrace_token": "mock-token"
        }

        status = collector.send_to_dynatrace(
            env,
            samples,
            credentials
        )

        self.assertEqual(status, 202)

    @patch.object(collector, "post")
    def test_dynatrace_rejected_sample(self, mock_post):
        mock_post.return_value = (
            202,
            json.dumps({
                "linesOk": 0,
                "linesInvalid": 1
            })
        )

        env = {
            "name": "dev",
            "cluster_name": "kafka-dev"
        }

        samples = [{
            "timestamp": "2026-11-04T18:31:00Z",
            "value": 100
        }]

        credentials = {
            "dynatrace_token": "mock-token"
        }

        with self.assertRaises(RuntimeError):
            collector.send_to_dynatrace(
                env,
                samples,
                credentials
            )

    def test_recovery_windows_cover_downtime(self):
        from datetime import datetime, timezone
        now = datetime(2026, 11, 4, 21, 0, tzinfo=timezone.utc)
        windows = collector.metric_windows("2026-11-04T18:00:00Z", now)
        self.assertGreater(len(windows), 1)
        self.assertEqual(windows[0][0].isoformat(), "2026-11-04T17:58:00+00:00")
        self.assertEqual(windows[-1][1].isoformat(), "2026-11-04T20:58:00+00:00")
        self.assertTrue(all(a[1] == b[0] for a, b in zip(windows, windows[1:])))

    def test_recovery_is_bounded(self):
        from datetime import datetime, timezone, timedelta
        now = datetime(2026, 11, 4, 21, 0, tzinfo=timezone.utc)
        windows = collector.metric_windows("2026-10-01T00:00:00Z", now)
        self.assertEqual(windows[0][0], now - timedelta(hours=24, minutes=2))

    def test_fresh_samples_deduplicate(self):
        samples = [
            {"timestamp": "2026-11-04T18:02:00Z", "value": 2},
            {"timestamp": "2026-11-04T18:01:00Z", "value": 1},
            {"timestamp": "2026-11-04T18:02:00Z", "value": 2},
            {"timestamp": "2026-11-04T18:03:00Z", "value": 3},
        ]
        result = collector.fresh_samples(samples, "2026-11-04T18:01:00Z")
        self.assertEqual([s["value"] for s in result], [2, 3])

    @patch.object(collector, "post")
    def test_query_rejects_full_page(self, mock_post):
        mock_post.return_value = (200, json.dumps({"data": [
            {"timestamp": "2026-11-04T18:00:00Z", "value": 1}
        ] * 1000}))
        from datetime import datetime, timezone, timedelta
        end = datetime(2026, 11, 4, 18, 15, tzinfo=timezone.utc)
        with self.assertRaisesRegex(RuntimeError, "query limit"):
            collector.query_metrics(
                {"cluster_id": "lkc-test"},
                {"metric": "metric", "confluent_metrics_url": "https://example.com"},
                {"confluent_key": "fake", "confluent_secret": "fake"},
                end - timedelta(minutes=15), end
            )


    def test_metric_specs_legacy_fallback(self):
        specs = collector.metric_specs({"metric": "io.confluent.kafka.server/received_bytes"})
        self.assertEqual(len(specs), 1)
        self.assertEqual(specs[0]["dynatrace_key"], "custom.confluent.dev.received_bytes")

    def test_metric_specs_validation(self):
        base = {"name": "a", "metric": "m", "dynatrace_key": "custom.x.y"}
        with self.assertRaises(ValueError):
            collector.metric_specs({"metrics": [base, dict(base)]})
        with self.assertRaises(ValueError):
            collector.metric_specs({"metrics": [dict(base, dynatrace_key="bad key!")]})
        with self.assertRaises(ValueError):
            collector.metric_specs({"metrics": [{"name": "a", "metric": "m"}]})

    def test_checkpoint_keys_keep_legacy_dev_key(self):
        self.assertEqual(collector.checkpoint_key("dev", {"name": "received_bytes"}), "dev")
        self.assertEqual(collector.checkpoint_key("dev", {"name": "consumer_lag"}), "dev:consumer_lag")

    def test_fresh_samples_keeps_different_groups_same_timestamp(self):
        samples = [
            {"timestamp": "2026-11-04T18:00:00Z", "value": 1, "metric.topic": "a"},
            {"timestamp": "2026-11-04T18:00:00Z", "value": 2, "metric.topic": "b"},
            {"timestamp": "2026-11-04T18:00:00Z", "value": 3, "metric.topic": "b"},
        ]
        result = collector.fresh_samples(samples, None)
        self.assertEqual(sorted(s["value"] for s in result), [1, 3])

    @patch.object(collector, "post")
    def test_query_sends_group_by_and_optional_agg(self, mock_post):
        mock_post.return_value = (200, json.dumps({"data": []}))
        from datetime import datetime, timezone, timedelta
        end = datetime(2026, 11, 4, 18, 15, tzinfo=timezone.utc)
        collector.query_metrics(
            {"cluster_id": "lkc-test"},
            {"metric": "m", "agg": "SUM", "group_by": ["metric.topic"],
             "confluent_metrics_url": "https://example.com"},
            {"confluent_key": "fake", "confluent_secret": "fake"},
            end - timedelta(minutes=15), end
        )
        payload = json.loads(mock_post.call_args[0][1])
        self.assertEqual(payload["group_by"], ["metric.topic"])
        self.assertEqual(payload["aggregations"][0]["agg"], "SUM")

    @patch.object(collector, "post")
    def test_send_uses_spec_key_and_dimensions(self, mock_post):
        mock_post.return_value = (202, json.dumps({"linesOk": 1, "linesInvalid": 0}))
        spec = {"dynatrace_key": "custom.confluent.dev.consumer_lag_offsets",
                "group_by": {"metric.consumer_group_id": "consumer_group", "metric.topic": "topic"}}
        collector.send_to_dynatrace(
            {"name": "dev", "cluster_name": "kafka-dev"},
            [{"timestamp": "2026-11-04T18:00:00Z", "value": 5,
              "metric.consumer_group_id": "dev.orders-consumers", "metric.topic": "dev.orders"}],
            {"dynatrace_token": "fake"}, spec)
        body = mock_post.call_args[0][1]
        body = body.decode() if isinstance(body, bytes) else body
        self.assertIn("custom.confluent.dev.consumer_lag_offsets,environment=dev,cluster=kafka-dev,"
                      "consumer_group=dev.orders-consumers,topic=dev.orders gauge,5 ", body)

    def test_escape_dimension(self):
        self.assertEqual(collector.escape_dimension("a b,c=d"), "a\\ b\\,c\\=d")


    def test_lookback_minutes_without_checkpoint(self):
        from datetime import datetime, timezone
        now = datetime(2026, 11, 5, 12, 0, tzinfo=timezone.utc)
        short = collector.metric_windows(None, now, lookback_minutes=20)
        long_ = collector.metric_windows(None, now, lookback_minutes=80)
        span = lambda w: (w[-1][1] - w[0][0]).total_seconds() / 60
        self.assertEqual(span(long_) - span(short), 60)

    @patch.object(collector, "save_checkpoints")
    @patch.object(collector, "query_metrics")
    def test_poll_environment_reports_failed_metric_and_continues(self, mock_query, mock_save):
        calls = []

        def fake(env, cfg, creds, start, end):
            calls.append(cfg["metric"])
            if cfg["metric"] == "bad":
                raise RuntimeError("boom")
            return 200, []

        mock_query.side_effect = fake
        specs = [
            {"name": "a", "metric": "bad", "dynatrace_key": "custom.a", "group_by": {}},
            {"name": "b", "metric": "good", "dynatrace_key": "custom.b", "group_by": {}},
        ]
        errors = []
        collector.poll_environment({"name": "dev", "cluster_id": "x", "cluster_name": "k"},
                                   specs, {"lookback_minutes": 80}, {}, {}, errors)
        self.assertEqual(errors, ["dev/a"])
        self.assertIn("good", calls)


if __name__ == "__main__":
    unittest.main()
