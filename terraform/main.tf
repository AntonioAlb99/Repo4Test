provider "azurerm" {
  features {}
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    project     = "custom-image"
  }
}

variable "number_of_vms" {
  type    = number
  default = 1
}

# ✅ Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-vm-apps"
  location = "westeurope"
  tags     = var.tags
}

# ✅ Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-infra"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# ✅ Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-infra"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ✅ Public IP pentru template
resource "azurerm_public_ip" "pip_template" {
  name                = "pip-template"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = var.tags
}

# ✅ NIC pentru template
resource "azurerm_network_interface" "nic_template" {
  name                = "nic-template"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_template.id
  }

  tags = var.tags
}

# ✅ VM Template (care va fi folosit pentru imagine)
resource "azurerm_windows_virtual_machine" "vm_template" {
  name                  = "vm-template"
  computer_name         = "template"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  admin_password        = "MySecurePassword123!"
  network_interface_ids = [azurerm_network_interface.nic_template.id]
  provision_vm_agent    = true
  enable_automatic_updates = false

  os_disk {
    name                 = "template-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  tags = var.tags
}

# ✅ Imagine din VM-ul template
resource "azurerm_image" "custom_image" {
  name                = "custom-win-image"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  os_disk {
    os_type         = "Windows"
    os_state        = "Generalized"
    managed_disk_id = azurerm_windows_virtual_machine.vm_template.storage_os_disk[0].managed_disk_id
    storage_type    = "Standard_LRS"
  }

  tags = var.tags
}

# ✅ Public IPs pentru fiecare VM final
resource "azurerm_public_ip" "public_ip" {
  count               = var.number_of_vms
  name                = "pip-vm-app-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = var.tags
}

# ✅ NIC-uri pentru fiecare VM final
resource "azurerm_network_interface" "nic" {
  count               = var.number_of_vms
  name                = "nic-vm-app-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }

  tags = var.tags
}

# ✅ VM-uri create din imagine
resource "azurerm_windows_virtual_machine" "vm" {
  count                 = var.number_of_vms
  name                  = "vm-app-${count.index}"
  computer_name         = "vmapp${count.index}"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  admin_password        = "MySecurePassword123!"
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  provision_vm_agent    = true

  os_disk {
    name                 = "osdisk-from-img-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = azurerm_image.custom_image.id

  tags = var.tags
}

resource "azurerm_image" "custom_image" {
  name                = "custom-win-image"
  location            = azurerm_resource_group.rg.location
  resource_group_name = "rg-vm-images"
  source_virtual_machine_id = "/subscriptions/f9810baf-3da2-4f67-ba39-79ff3fd73156/resourceGroups/rg-vm-apps/providers/Microsoft.Compute/virtualMachines/vm-template"
}
