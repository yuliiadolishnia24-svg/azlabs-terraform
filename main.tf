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

# Отримуємо дані про поточну підписку
data "azurerm_subscription" "current" {}

# TASK 1: Створення Resource Group з тегами
resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "East US"

  tags = {
    "Cost Center" = "000"
  }
}

# TASK 2: Призначення політики "Require a tag and its value"
resource "azurerm_resource_group_policy_assignment" "require_tag" {
  name                 = "require-cost-center-tag"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1a311c306d9"
  display_name         = "Require Cost Center tag and its value 000"

  parameters = <<PARAMS
    {
      "tagName": { "value": "Cost Center" },
      "tagValue": { "value": "000" }
    }
PARAMS
}

# TASK 3: Політика успадкування тегів (Inherit tag from RG)
resource "azurerm_resource_group_policy_assignment" "inherit_tag" {
  name                 = "inherit-cost-center-tag"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/cd3aa116-8854-41c7-b088-89958f3ad6d8"
  display_name         = "Inherit the Cost Center tag from the RG if missing"

  location = "East US"
  identity { type = "SystemAssigned" }

  parameters = <<PARAMS
    {
      "tagName": { "value": "Cost Center" }
    }
PARAMS
}

# TASK 4: Створення блокування (Resource Lock)
resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
  notes      = "Заборона видалення Resource Group для Lab 2b"
}