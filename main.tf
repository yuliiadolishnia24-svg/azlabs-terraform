# 1. Група ресурсів
resource "azurerm_resource_group" "rg" {
  name     = "az104-rg9b"
  location = "polandcentral"
}

# 2. Контейнерна група (ACI)
resource "azurerm_container_group" "aci" {
  name                = "az104-c1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  dns_name_label      = "yuliia-aci-lab" # Зміни на унікальне, якщо буде помилка
  os_type             = "Linux"

  container {
    name   = "hello-world"
    image  = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  tags = {
    environment = "testing"
    lab         = "09b"
  }
}

# 3. Вивід адреси сайту після розгортання
output "container_fqdn" {
  value = azurerm_container_group.aci.fqdn
}