# 1. Група ресурсів
resource "azurerm_resource_group" "rg" {
  name     = "az104-rg9"
  location = "eastus"
}

# 2. План сервісу (Hardware)
resource "azurerm_service_plan" "plan" {
  name                = "az104-plan9"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "P1v3" # Premium V3 як у завданні
}

# 3. Сам веб-додаток (Production)
resource "azurerm_linux_web_app" "webapp" {
  name                = "webapp-yuliia-unique" 
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      php_version = "8.2"
    }
  }
}

# 4. Слот розгортання (Staging)
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.webapp.id

  site_config {
    application_stack {
      php_version = "8.2"
    }
  }
}