# 1. Налаштування провайдера Azure
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
resource "azurerm_resource_group" "rg8" {
  name     = "az104-rg8"
  location = "East US"
}

# 3. Віртуальна мережа та підмережа (Task 1 & 3)
resource "azurerm_virtual_network" "vnet" {
  name                = "vmss-vnet"
  address_space       = ["10.82.0.0/20"]
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name
}

resource "azurerm_subnet" "subnet0" {
  name                 = "subnet0"
  resource_group_name  = azurerm_resource_group.rg8.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.82.0.0/24"]
}

# --- TASK 1: ZONE-RESILIENT VIRTUAL MACHINES ---

# Публічні IP для VM
resource "azurerm_public_ip" "vm_pip" {
  count               = 2
  name                = "az104-vm${count.index + 1}-pip"
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [tostring(count.index + 1)]
}

# Мережеві інтерфейси для VM
resource "azurerm_network_interface" "vm_nic" {
  count               = 2
  name                = "az104-nic${count.index + 1}"
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet0.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip[count.index].id
  }
}

# Віртуальні машини (vm1 в Zone 1, vm2 в Zone 2)
resource "azurerm_windows_virtual_machine" "vms" {
  count               = 2
  name                = "az104-vm${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  size                = "Standard_B2s" # Економний розмір для лаби
  admin_username      = "localadmin"
  admin_password      = "Pa55w.rd1234!"
  zone                = tostring(count.index + 1)

  network_interface_ids = [azurerm_network_interface.vm_nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# --- TASK 2: STORAGE SCALING (ADD DATA DISK TO VM1) ---

resource "azurerm_managed_disk" "disk1" {
  name                 = "vm1-disk1"
  location             = azurerm_resource_group.rg8.location
  resource_group_name  = azurerm_resource_group.rg8.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach_disk1" {
  managed_disk_id    = azurerm_managed_disk.disk1.id
  virtual_machine_id = azurerm_windows_virtual_machine.vms[0].id
  lun                = "10"
  caching            = "ReadWrite"
}

# --- TASK 3: VIRTUAL MACHINE SCALE SET (VMSS) ---

# Публічний IP для балансувальника VMSS
resource "azurerm_public_ip" "vmss_lb_pip" {
  name                = "vmss-lb-pip"
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Балансувальник для Scale Set
resource "azurerm_lb" "vmss_lb" {
  name                = "vmss-lb"
  location            = azurerm_resource_group.rg8.location
  resource_group_name = azurerm_resource_group.rg8.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vmss_lb_pip.id
  }
}

# Сам Scale Set
resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = "vmss1"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  sku                 = "Standard_B2s"
  instances           = 2
  admin_password      = "Pa55w.rd1234!"
  admin_username      = "localadmin"
  upgrade_mode        = "Automatic"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Premium_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet0.id
    }
  }
}

# --- TASK 4: AUTOSCALE SETTINGS ---

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.rg8.name
  location            = azurerm_resource_group.rg8.location
  target_resource_id  = azurerm_windows_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    # Правило Scale Out (якщо CPU > 70% протягом 10 хв)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }

    # Правило Scale In (якщо CPU < 30% протягом 10 хв)
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      scale_action {
        direction = "Decrease"
        type      = "PercentChangeCount"
        value     = "50"
        cooldown  = "PT5M"
      }
    }
  }
}