terraform {
  backend "azurerm" {
    resource_group_name  = "storage"
    storage_account_name = "sttfstateexample01"
    container_name       = "tfstate"
    key                  = "applications-dev.tfstate"
    use_azuread_auth     = true
    use_cli              = true
  }
}
