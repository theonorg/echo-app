terraform {
  backend "azurerm" {
        resource_group_name  = "tasb-tfstate-rg"
        storage_account_name = "tasbtfstatestg"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  use_oidc = true
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.appName}-${var.appServiceName}-${var.env}-rg"
  location = var.location
}

# Azure App Configuration
resource "azurerm_app_configuration" "appconfig" {
  name                = "${var.appName}-${var.appServiceName}-${var.env}-config"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "standard"
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = "asp-${var.appName}-${var.appServiceName}-${var.env}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B2"
}

#Create the web app, pass in the App Service Plan ID, and deploy code from a public GitHub repo
resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.appName}-${var.appServiceName}-${var.env}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan.id

  app_settings = {
    "AppConfigConnString" = azurerm_app_configuration.appconfig.primary_read_key[0].connection_string
  }

  site_config {
    always_on = true
    application_stack {
      dotnet_version = "6.0"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "appconf_dataowner" {
  scope                = azurerm_app_configuration.appconf.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_app_configuration_feature" "test" {
  configuration_store_id = azurerm_app_configuration.appconf.id
  description            = "GetLogs button"
  name                   = "GetLogs"
  enabled                = true
}