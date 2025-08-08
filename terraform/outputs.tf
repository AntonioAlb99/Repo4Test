output "vm_public_ips" {
 value = [for ip in azurerm_public_ip.public_ip : ip.ip_address]
}
