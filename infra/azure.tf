/*
  The terraform code will deploy the following Azure resources:
    1. Resource Group
    2. ACR
    3. AKS (Basic)
  Author : Heinz Ramos
*/
# ------------------------------------------------------------
#  Variables
# ------------------------------------------------------------
variable "rg_name" {
  default     = "rg-resourcegroup"
  description = "Name of the resource group"
}
variable "rg_location" {
  default     = "East US"
  description = "Location of resource group"
}
variable "environment" {
  default = "environment"
}
variable "app_name" {
  default = "appname"
}
variable "aks_node_count" {
  default = 1
}
variable "acr_name" {
  default = "acrsensorsqc"
}
locals {
  # Hash of Tags
  common_tags = {
    "Deployment Method" = "Terraform"
    "Author"            = "Heinz Ramos"
    "Environment"       = var.environment
    "App Name"          = var.app_name
  }
}

# ------------------------------------------------------------
#  Main
# ------------------------------------------------------------
# Azure Connection, assume connection is made using Azure CLI
provider "azurerm" {
  /*
    Only required if Azure CLI authentication is having issues
    This will use an Azure Service Principal with contributor rights to the sbuscription

    subscription_id = "XXXXXXXXXXXXXXXXXXXXXXXXXXX"
    client_id       = "XXXXXXXXXXXXXXXXXXXXXXXXXXX"
    client_secret   = "XXXXXXXXXXXXXXXXXXXXXXXXXXX"
    tenant_id       = "XXXXXXXXXXXXXXXXXXXXXXXXXXX"
  */
  features {}
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "${var.rg_name}-${var.environment}"
  location = var.rg_location
  tags     = local.common_tags
}

# Create a Random String
resource "random_string" "app_id" {
  length  = 4
  special = false
}

# Create ACR
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.common_tags
}

# Create AKS
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.app_name}${lower(random_string.app_id.result)}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.app_name

  default_node_pool {
    name       = "agentpool"
    node_count = var.aks_node_count
    vm_size    = "Standard_D2_v2"
  }

  addon_profile {
    http_application_routing {
      enabled = false
    }
    kube_dashboard {
      enabled = false
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Add the role to the identity the kubernetes cluster was assigned
resource "azurerm_role_assignment" "aks_to_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# ------------------------------------------------------------
#  Outputs
# ------------------------------------------------------------
output "resourcegroup_name" {
  value = azurerm_resource_group.rg.name
}
output "resourcegroup_location" {
  value = azurerm_resource_group.rg.location
}
output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}
output "aks_server_name" {
  value = azurerm_kubernetes_cluster.aks.name
}
