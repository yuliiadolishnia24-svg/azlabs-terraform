# 1. Група ресурсів
resource "azurerm_resource_group" "rg" {
  name     = "az104-rg10-rg1"
  location = "polandcentral"
}

# 2. Мережа для VM
resource "azurerm_virtual_network" "vnet" {
  name                = "az104-10-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

# 3. Мережевий інтерфейс (без Public IP)
resource "azurerm_network_interface" "nic" {
  name                = "az104-10-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 4. Віртуальна машина (Standard_B2s_v2)
resource "azurerm_windows_virtual_machine" "vm" {
  name                = "az104-10-vm0"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s_v2"
  admin_username      = "localadmin"
  admin_password      = "YourComplexPassword123!"

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# 5. Recovery Services Vault
resource "azurerm_recovery_services_vault" "vault" {
  name                = "az104-rsv-region1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  soft_delete_enabled = true
}

# 6. Політика бекапу
resource "azurerm_backup_policy_vm" "policy" {
  name                = "az104-backup-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  backup {
    frequency = "Daily"
    time      = "00:00"
  }

  retention_daily {
    count = 7
  }
}