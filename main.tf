# 1. Група ресурсів
resource "azurerm_resource_group" "rg" {
  name     = "az104-rg9c"
  location = "polandcentral"
}

# 2. Лог-аналітика (потрібна для середовища Container Apps)
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "logs-9c"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Середовище Container App (Environment)
resource "azurerm_container_app_environment" "env" {
  name                       = "my-environment"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

# 4. Сам застосунок Container App
resource "azurerm_container_app" "app" {
  name                         = "my-app-yuliia"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "hello-world-container"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}