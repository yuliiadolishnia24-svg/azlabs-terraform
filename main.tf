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

# 1. Створюємо групу
resource "azurerm_resource_group" "rg2" {
  name     = "az104-rg2"
  location = "East US"
  tags = {
    "Cost Center" = "000"
  }
}

# 2. Шукаємо вбудовану політику "Require a tag..." за назвою
data "azurerm_policy_definition" "require_tag_def" {
  display_name = "Require a tag and its value on resources"
}

# 3. Шукаємо вбудовану політику "Inherit a tag..." за назвою
data "azurerm_policy_definition" "inherit_tag_def" {
  display_name = "Inherit a tag from the resource group if missing"
}

# TASK 2: Призначення обов'язкового тегу
resource "azurerm_resource_group_policy_assignment" "require_tag" {
  name                 = "require-tag-assignment"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.require_tag_def.id
  display_name         = "Require Cost Center tag"

  parameters = jsonencode({
    tagName  = { value = "Cost Center" }
    tagValue = { value = "000" }
  })
}

# TASK 3: Призначення успадкування тегу
resource "azurerm_resource_group_policy_assignment" "inherit_tag" {
  name                 = "inherit-tag-assignment"
  resource_group_id    = azurerm_resource_group.rg2.id
  policy_definition_id = data.azurerm_policy_definition.inherit_tag_def.id
  display_name         = "Inherit Cost Center tag"
  location             = "East US"
  identity { type = "SystemAssigned" }

  parameters = jsonencode({
    tagName = { value = "Cost Center" }
  })
}

# TASK 4: Блокування на видалення
resource "azurerm_management_lock" "rg_lock" {
  name       = "rg-lock"
  scope      = azurerm_resource_group.rg2.id
  lock_level = "CanNotDelete"
}