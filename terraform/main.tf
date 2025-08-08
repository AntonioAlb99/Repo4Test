provider "azurerm" {
  features {}
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

# ✅ Public IPs pentru fiecare VM
resource "azurerm_public_ip" "public_ip" {
  count               = var.number_of_vms
  name                = "pip-vm-app-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  tags                = var.tags
}

# ✅ NIC-uri pentru VM-uri
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

# ✅ VM-urile finale create din imagine
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

  # ⬇️ Imagine deja existentă
  source_image_id = "/subscriptions/f9810baf-3da2-4f67-ba39-79ff3fd73156/resourceGroups/rg-vm-images/providers/Microsoft.Compute/images/custom-win-image"

  tags = var.tags
}

resource "azurerm_image" "custom_image" {
  name                = "custom-win-image"
  location            = azurerm_resource_group.rg.location
  resource_group_name = "rg-vm-images"
  source_virtual_machine_id = "/subscriptions/f9810baf-3da2-4f67-ba39-79ff3fd73156/resourceGroups/rg-vm-apps/providers/Microsoft.Compute/virtualMachines/vm-template"
}
