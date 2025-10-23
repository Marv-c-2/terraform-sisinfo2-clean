terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.23.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5"
    }
  }
}

provider "azurerm" {
  features {}

  client_id       = var.client_id
  client_secret   = var.client_secret
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Genera un número aleatorio para evitar conflictos
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "gr-sisinfo-entel-${random_integer.suffix.result}"
  location = "chilecentral"
}

# Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "saucbenteldelta${random_integer.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
}

resource "azurerm_storage_container" "raw_entel" {
  name                  = "raw-entel"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "blob"
}

# Blobs (usa rutas absolutas de Windows)
resource "azurerm_storage_blob" "_03csv" {
  name                   = "03.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_entel.name
  type                   = "Block"
  source                 = "C:/Users/MARVIN/Documents/terraform-sisinfo2-clean/Dataset/03.csv"
}

resource "azurerm_storage_blob" "_05csv" {
  name                   = "05.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_entel.name
  type                   = "Block"
  source                 = "C:/Users/MARVIN/Documents/terraform-sisinfo2-clean/Dataset/05.csv"
}

resource "azurerm_storage_blob" "_06csv" {
  name                   = "06.csv"
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.raw_entel.name
  type                   = "Block"
  source                 = "C:/Users/MARVIN/Documents/terraform-sisinfo2-clean/Dataset/06.csv"
}

# SQL Server
resource "azurerm_mssql_server" "db" {
  name                         = "sql-ucb-sisinfo-entel-delta-${random_integer.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.admin_login
  administrator_login_password = var.admin_password
}

resource "azurerm_mssql_firewall_rule" "rulefirewall" {
  name             = "FirewallRule1"
  server_id        = azurerm_mssql_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

resource "azurerm_mssql_database" "dw_entel" {
  name                  = "dw_entel_delta"
  server_id             = azurerm_mssql_server.db.id
  collation             = "SQL_Latin1_General_CP1_CI_AS"
  license_type          = "LicenseIncluded"
  max_size_gb           = 2
  sku_name              = "S0"
  enclave_type          = "VBS"
  storage_account_type  = "Local"  # <- compatible con chilecentral

  tags = {
    foo = "bar"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Data Factory
resource "azurerm_data_factory" "df" {
  name                = "adf-ucb-dw-entel-${random_integer.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
