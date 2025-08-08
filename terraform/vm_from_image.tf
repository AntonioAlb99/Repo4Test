provider "azurerm" {
  features {}
}

resource "azurerm_image" "custom_image" {
  name                    = "custom-image-app"
  location                = "westeurope"
  resource_group_name     = "rg-vm-apps"
  source_virtual_machine_id = "/subscriptions/<subscription_id>/resourceGroups/rg-vm-apps/providers/Microsoft.Compute/virtualMachines/template-vm-app"
}

resource "azurerm_public_ip" "public_ip" {
  count               = var.number_of_vms
  name                = "pip-app-${count.index}"
  location            = "westeurope"
  resource_group_name = "rg-vm-apps"
  allocation_method   = "Static"
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  count               = var.number_of_vms
  name                = "nic-app-${count.index}"
  location            = "westeurope"
  resource_group_name = "rg-vm-apps"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = "/subscriptions/<subscription_id>/resourceGroups/rg-vm-apps/providers/Microsoft.Network/virtualNetworks/vnet-apps/subnets/subnet-apps"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[count.index].id
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  count                  = var.number_of_vms
  name                   = "vm-app-${count.index}"
  resource_group_name    = "rg-vm-apps"
  location               = "westeurope"
  size                   = "Standard_B2s"
  admin_username         = "azureuser"
  admin_password         = "MySecurePassword123!"
  network_interface_ids  = [azurerm_network_interface.nic[count.index].id]
  provision_vm_agent     = true

  os_disk {
    name                 = "osdisk-app-${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_id = azurerm_image.custom_image.id

  tags = var.tags
}
