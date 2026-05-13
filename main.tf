# 1. Провайдер Azure
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 2. Група ресурсів
resource "azurerm_resource_group" "rg" {
  name     = "az104-rg11"
  location = "polandcentral"
}

# 3. Log Analytics Workspace (для Task 6)
resource "azurerm_log_analytics_workspace" "law" {
  name                = "az104-11-law"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 4. Action Group (для Task 3 - виправлений email)
resource "azurerm_monitor_action_group" "alerts" {
  name                = "Alert the operations team"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "AlertOpsTeam"

  email_receiver {
    name                    = "VM was deleted"
    email_address           = "yuliia.dolishnia@gmail.com" 
    use_common_alert_schema = true
  }
}

# 5. Activity Log Alert (для Task 2)
resource "azurerm_monitor_activity_log_alert" "vm_delete_alert" {
  name                = "VM_Deleted_Alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [data.azurerm_subscription.current.id]
  description         = "A VM in your resource group was deleted"

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Compute/virtualMachines/delete"
    status         = "Succeeded"
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

data "azurerm_subscription" "current" {}