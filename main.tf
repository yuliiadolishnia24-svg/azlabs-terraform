# 1. Провайдери (тепер нам потрібен і AzureAD, і AzureRM)
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

# 2. TASK 1: Створення Management Group
resource "azurerm_management_group" "mg1" {
  display_name = "az104-mg1"
  name         = "az104-mg1" # ID має бути унікальним
}

# 3. Підготовка: Створюємо групу Help Desk (якщо її ще немає)
resource "azuread_group" "helpdesk" {
  display_name     = "helpdesk"
  security_enabled = true
}

# 4. TASK 2: Призначення вбудованої ролі "Virtual Machine Contributor"
resource "azurerm_role_assignment" "vm_contributor" {
  scope                = azurerm_management_group.mg1.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azuread_group.helpdesk.object_id
}

# 5. TASK 3: Створення Custom RBAC Role
resource "azurerm_role_definition" "custom_support" {
  name        = "Custom Support Request"
  scope       = azurerm_management_group.mg1.id
  description = "A custom contributor role for support requests."

  permissions {
    actions     = ["Microsoft.Support/*"]
    # Виключаємо дозвіл на реєстрацію провайдера (як у завданні)
    not_actions = ["Microsoft.Support/register/action"]
  }

  assignable_scopes = [
    azurerm_management_group.mg1.id
  ]
}