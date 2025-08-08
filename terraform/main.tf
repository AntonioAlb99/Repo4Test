provider "azurerm" {
  features {}
}

# ✅ Resource Group pentru aplicații (VM-urile finale)
resource "azurerm_resource_group" "rg_apps" {
  name     = "rg-vm-apps"
  location = "westeurope"
  tags     = var.tags
}

# ✅ Resource Group pentru imagini
resource "azurerm_resource_group" "rg_images" {
  name     = "rg-vm-images"
  location = "westeurope"
  tags     = var.tags
}

# ✅ VNET + Subnet (în RG apps)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-infra"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg_apps.location
  resource_group_name = azurerm_resource_group.rg_apps.name
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-infra"
  resource_group_name  = azurerm_resource_group.rg_apps.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ✅ NIC pentru template
resource "azurerm_network_interface" "template_nic" {
  name                = "nic-template-vm"
  location            = azurerm_resource_group.rg_apps.location
  resource_group_name = azurerm_resource_group.rg_apps.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# ✅ Template VM (va fi folosit pentru imagine)
resource "azurerm_windows_virtual_machine" "template_vm" {
  name                  = "vm-template"
  computer_name         = "vmtemplate"
  resource_group_name   = azurerm_resource_group.rg_apps.name
  location              = azurerm_resource_group.rg_apps.location
  size                  = "Standard_B2s"
  admin_username        = "azureuser"
  admin_password        = "MySecurePassword123!"
  network_interface_ids = [azurerm_network_interface.template_nic.id]
  provision_vm_agent    = true

  os_disk {
    name                 = "osdisk-template"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }

  tags = var.tags
}

# ✅ Creează imagine din template VM
resource "azurerm_image" "custom_image" {
  name                = "custom-win-image"
  location            = azurerm_resource_group.rg_images.location
  resource_group_name = azurerm_resource_group.rg_images.name

  os_disk {
    os_type  = "Windows"
    os_state = "Generalized"
    blob_uri = null
    managed_disk_id = azurerm_windows_virtual_machine.template_vm.os_disk.id
    storage_type = "Standard_LRS"
  }

  tags = var.tags
}

# ✅ Public IPs pentru VM-urile finale
resource "azurerm_public_ip" "public_ip" {
  count               = var.number_of_vms
  name                = "pip-vm-app-${count.index}"
  location            = azurerm_resource_group.rg_apps.location
  resource_group_name = azurerm_resource_group.rg_apps.name
  allocation_method   = "Static"
  tags                = var.tags
}

# ✅ NIC-uri pentru VM-uri finale
resource "azurerm_network_interface" "nic" {
  count               = var.number_of_vms
  name                = "nic-vm-app-${count.index}"
  location            = azurerm_resource_group.rg_apps.location
  resource_group_name = azurerm_resource_group.rg_apps.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }

  tags = var.tags
}

# ✅ VM-uri finale create din imaginea personalizată
resource "azurerm_windows_virtual_machine" "vm" {
  count                  = var.number_of_vms
  name                   = "vm-app-${count.index}"
  computer_name          = "vmapp${count.index}"
  resource_group_name    = azurerm_resource_group.rg_apps.name
  location               = azurerm_resource_group.rg_apps.location
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

  tags = var.tags
}
