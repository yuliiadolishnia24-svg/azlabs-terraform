terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

# Отримання даних про домен вашої організації
data "azuread_domains" "default" {
  only_initial = true
}

# TASK 1: Створення користувача az104-user2 (змінено, щоб не було конфлікту)
resource "azuread_user" "user1" {
  user_principal_name = "az104-user2@${data.azuread_domains.default.domains[0].domain_name}"
  display_name        = "az104-user2"
  password            = "Password12345!"
  job_title           = "IT Lab Administrator"
  department          = "IT"
  usage_location      = "US"
}

# TASK 2: Створення групи IT Lab Administrators та додавання користувача
resource "azuread_group" "admins" {
  display_name     = "IT Lab Administrators"
  security_enabled = true
  description      = "Administrators that manage the IT lab"
  members          = [azuread_user.user1.object_id]
}