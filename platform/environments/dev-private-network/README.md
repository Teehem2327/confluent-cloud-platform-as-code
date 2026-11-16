# DEV private networking (switched off)

Azure Private Link for an Enterprise Confluent Cloud cluster, in its own Terraform root
and state (`platform-dev-private-network.tfstate`). It does not touch `kafka-dev`.

| Switch | Creates | Cost |
|---|---|---|
| `deploy_private_networking` | Confluent gateway and access point; Azure VNet, private endpoint, private DNS | Private endpoint hourly fee |
| `deploy_private_cluster` | Enterprise cluster `kafka-dev-private` | Hourly eCKU charge |

Both default to `false`. Deploy for a short window, capture evidence, then destroy this root.

## One-time bootstrap (least privilege)

Create the resource group `rg-confluent-private-dev` once by hand, then give the pipeline identity
(`sp-azdo-confluent-terraform`) the **Contributor** role on that group only. Terraform reads the group and
builds everything else inside it, so the identity needs no write access elsewhere in the subscription.

## Status: previewed, not deployed

The code, the preview pipeline (`platform-dev-private-network-plan`), the gated apply pipeline
(`platform-dev-private-network-apply`) and the gated destroy pipeline (`platform-dev-private-network-destroy`)
are in place and preview-tested. The root has never been applied, to avoid the hourly cost of the Enterprise cluster.

To deploy for a short window: run the apply pipeline with Apply ticked, the confirmation text
`deploy-private-network` and approval at `confluent-dev`, capture evidence, then run the destroy pipeline the same day.

Not proven by a preview: the private endpoint connection being approved and DNS resolving, and Confluent accepting the
Enterprise cluster settings (the availability value is only validated when applied).
