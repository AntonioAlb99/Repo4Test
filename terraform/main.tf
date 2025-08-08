provider "azurerm" {
  features {}
}

# ✅ Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-vm-images"
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

# ✅ NIC for Template VM
resource "azurerm_network_interface" "nic_template" {
  name                = "nic-template-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# ✅ Template VM
resource "azurerm_windows_virtual_machine" "template_vm" {
  name                  = "template-vm-app"
  computer_name         = "tmplvm"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  admin_password        = "MySecurePassword123!"
  network_interface_ids = [azurerm_network_interface.nic_template.id]
  provision_vm_agent    = true

  os_disk {
    name                 = "osdisk-template-app"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/installers/npp.ps1"))
  tags        = var.tags
}

# ✅ Create Image from Template VM
resource "azurerm_image" "custom_image" {
  name                      = "custom-win-image"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  source_virtual_machine_id = azurerm_windows_virtual_machine.template_vm.id

  depends_on = [
    azurerm_windows_virtual_machine.template_vm
  ]
}

# ✅ Public IPs for each VM
resource "azurerm_public_ip" "public_ip" {
  count               = var.number_of_vms
  name                = "pip-vm-app-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = var.tags
}

# ✅ NICs for cloned VMs
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

# ✅ Cloned VMs from Custom Image
resource "azurerm_windows_virtual_machine" "vm" {
  count                  = var.number_of_vms
  name                   = "vm-app-${count.index}"
  computer_name          = "vmapp${count.index}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  size                   = "Standard_B2s"
  admin_username         = "azureuser"
  admin_password         = "MySecurePassword123!"
  network_interface_ids  = [azurerm_network_interface.nic[count.index].id]
  provision_vm_agent     = true

  os_disk {
    name                 = "osdisk-from-img-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = azurerm_image.custom_image.id
  tags            = var.tags
}
