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

# ЗМІНЕНО: Новий регіон East US 2
resource "azurerm_resource_group" "rg5" {
  name     = "az104-rg5"
  location = "East US 2" 
}

# --- МЕРЕЖА 1: CoreServices ---
resource "azurerm_virtual_network" "core_vnet" {
  name                = "CoreServicesVnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
}

resource "azurerm_subnet" "core_subnet" {
  name                 = "CoreSubnet"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "perimeter" {
  name                 = "perimeter"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.core_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- МЕРЕЖА 2: Manufacturing ---
resource "azurerm_virtual_network" "mfg_vnet" {
  name                = "ManufacturingVnet"
  address_space       = ["172.16.0.0/16"]
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
}

resource "azurerm_subnet" "mfg_subnet" {
  name                 = "ManufacturingSubnet"
  resource_group_name  = azurerm_resource_group.rg5.name
  virtual_network_name = azurerm_virtual_network.mfg_vnet.name
  address_prefixes     = ["172.16.0.0/24"]
}

# --- TASK 4: VNET PEERING ---
resource "azurerm_virtual_network_peering" "core_to_mfg" {
  name                      = "CoreToManufacturing"
  resource_group_name       = azurerm_resource_group.rg5.name
  virtual_network_name      = azurerm_virtual_network.core_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.mfg_vnet.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "mfg_to_core" {
  name                      = "ManufacturingToCore"
  resource_group_name       = azurerm_resource_group.rg5.name
  virtual_network_name      = azurerm_virtual_network.mfg_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.core_vnet.id
  allow_forwarded_traffic   = true
}

# --- Мережеві інтерфейси ---
resource "azurerm_network_interface" "core_nic" {
  name                = "CoreVM-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.core_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "mfg_nic" {
  name                = "MfgVM-nic"
  location            = azurerm_resource_group.rg5.location
  resource_group_name = azurerm_resource_group.rg5.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mfg_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# --- TASK 1 & 2: VM (Використовуємо надійний Standard_D2s_v3) ---
resource "azurerm_windows_virtual_machine" "core_vm" {
  name                = "CoreVM"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!"
  network_interface_ids = [azurerm_network_interface.core_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_windows_virtual_machine" "mfg_vm" {
  name                = "MfgVM"
  resource_group_name = azurerm_resource_group.rg5.name
  location            = azurerm_resource_group.rg5.location
  size                = "Standard_D2s_v3"
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!"
  network_interface_ids = [azurerm_network_interface.mfg_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-Datacenter"
    version   = "latest"
  }
}

# --- TASK 6: Route Table ---
resource "azurerm_route_table" "rt" {
  name                          = "rt-CoreServices"
  location                      = azurerm_resource_group.rg5.location
  resource_group_name           = azurerm_resource_group.rg5.name
  bgp_route_propagation_enabled = true

  route {
    name                   = "PerimetertoCore"
    address_prefix         = "10.0.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.7"
  }
}

resource "azurerm_subnet_route_table_association" "assoc" {
  subnet_id      = azurerm_subnet.perimeter.id
  route_table_id = azurerm_route_table.rt.id
}