terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.99.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "sdwan_edge_rg" {
  name     = var.resource_group
  location = var.location
}

resource "azurerm_virtual_network" "sdwan_edge_vnet" {
  name                = "sdwan-edge-vnet"
  address_space       = [var.address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.sdwan_edge_rg.name
}

resource "azurerm_subnet" "sdwan_subnet_lan" {
  name                 = "sdwan-subnet-lan"
  resource_group_name  = azurerm_resource_group.sdwan_edge_rg.name
  virtual_network_name = azurerm_virtual_network.sdwan_edge_vnet.name
  address_prefixes     = [var.sdwan_subnet_lan]
}

resource "azurerm_subnet" "sdwan_subnet_wan" {
  name                 = "sdwan-subnet-wan"
  resource_group_name  = azurerm_resource_group.sdwan_edge_rg.name
  virtual_network_name = azurerm_virtual_network.sdwan_edge_vnet.name
  address_prefixes     = [var.sdwan_subnet_wan]
}

resource "azurerm_network_security_group" "sdwan_nsg_wan" {
  name                = "sdwan-nsg-wan"
  location            = var.location
  resource_group_name = azurerm_resource_group.sdwan_edge_rg.name
}


resource "azurerm_network_security_rule" "sdwan_nsg_rule_wan1" {
  name                        = "allow-ssh"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.sdwan_edge_rg.name
  network_security_group_name = azurerm_network_security_group.sdwan_nsg_wan.name
}

resource "azurerm_network_security_rule" "sdwan_nsg_rule_wan2" {
  name                        = "allow-https"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.sdwan_edge_rg.name
  network_security_group_name = azurerm_network_security_group.sdwan_nsg_wan.name
}

resource "azurerm_network_security_rule" "sdwan_nsg_rule_wan3" {
  name                        = "allow-UDP"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "12346-13046"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.sdwan_edge_rg.name
  network_security_group_name = azurerm_network_security_group.sdwan_nsg_wan.name
}

resource "azurerm_subnet_network_security_group_association" "sdwan_nsg_associate_wan" {
  subnet_id                 = azurerm_subnet.sdwan_subnet_wan.id
  network_security_group_id = azurerm_network_security_group.sdwan_nsg_wan.id
}


resource "azurerm_public_ip" "sdwan_public_ip_edge_wan" {
  name                = "sdwan-public-ip-edge-wan"
  location            = var.location
  resource_group_name = azurerm_resource_group.sdwan_edge_rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "sdwan_edge_wan_nic" {
  name                = "sdwan-edge-wan-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.sdwan_edge_rg.name

  ip_configuration {
    name                          = "sdwan-wan-ipconfig"
    subnet_id                     = azurerm_subnet.sdwan_subnet_wan.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.sdwan_public_ip_edge_wan.id
  }
}

resource "azurerm_network_interface" "sdwan_edge_lan_nic" {
  name                = "sdwan-edge-lan-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.sdwan_edge_rg.name

  ip_configuration {
    name                          = "sdwan-lan-ipconfig"
    subnet_id                     = azurerm_subnet.sdwan_subnet_lan.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Accept Cisco SDWAN image in Azure Market place
resource "azurerm_marketplace_agreement" "cisco" {
  publisher = "cisco"
  offer     = "cisco-c8000v"
  plan      = var.sku
}

# Generate random text for a unique storage account name for edges
resource "random_id" "randomId" {
  keepers = {
    resource_group_name = azurerm_resource_group.sdwan_edge_rg.name
  }

  byte_length = 4
}

# Create storage account for boot diagnostics of edge VM 
resource "azurerm_storage_account" "storageaccountedge" {
  name                     = "edgediag${random_id.randomId.hex}"
  resource_group_name      = azurerm_resource_group.sdwan_edge_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_virtual_machine" "c8000v_vm" {
  name                  = var.c8000v_vm
  location              = var.location
  resource_group_name   = azurerm_resource_group.sdwan_edge_rg.name
  vm_size               = var.edge_vm_size
  network_interface_ids = [azurerm_network_interface.sdwan_edge_wan_nic.id, azurerm_network_interface.sdwan_edge_lan_nic.id]
  primary_network_interface_id = azurerm_network_interface.sdwan_edge_wan_nic.id

  storage_image_reference {
    publisher = "cisco"
    offer     = "cisco-c8000v"
    sku       = var.sku
    version   = var.image_version
  }

  plan {
    publisher = "cisco"
    product   = "cisco-c8000v"
    name      = var.name
  }
  
  storage_os_disk {
    name              = "c8000v-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "c8000v-vm"
    admin_username = "adminuser"
    admin_password = "P@ssw0rd123!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = azurerm_storage_account.storageaccountedge.primary_blob_endpoint
  }
}
