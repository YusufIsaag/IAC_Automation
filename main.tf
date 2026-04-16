terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
}

data "azurerm_resource_group" "rg" {
  name = "ke02-2526-KD-groep06"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-dbf-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_subnet" "frontend_subnet" {
  name                 = "snet-frontend-prd"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "snet-backend-prd"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "frontend_nsg" {
  name                = "nsg-frontend-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_network_security_group" "backend_nsg" {
  name                = "nsg-backend-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_network_security_rule" "frontend_allow_ssh" {
  name                        = "allow-ssh"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.frontend_nsg.name
}

resource "azurerm_network_security_rule" "frontend_allow_http" {
  name                        = "allow-http"
  priority                    = 1010
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.frontend_nsg.name
}

resource "azurerm_network_security_rule" "backend_allow_postgres" {
  name                        = "allow-postgres"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.backend_nsg.name
}

resource "azurerm_public_ip" "frontend_ip" {
  name                = "pip-web-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_subnet_network_security_group_association" "frontend_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.frontend_subnet.id
  network_security_group_id = azurerm_network_security_group.frontend_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "backend_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.backend_subnet.id
  network_security_group_id = azurerm_network_security_group.backend_nsg.id
}

resource "azurerm_network_interface" "frontend_nic" {
  name                = "nic-web-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-web-prd"
    subnet_id                     = azurerm_subnet.frontend_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.frontend_ip.id
  }

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_network_interface" "backend_nic" {
  name                = "nic-db-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-db-prd"
    subnet_id                     = azurerm_subnet.backend_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_ssh_public_key" "ssh_key" {
  name                = "sshkey-dbf-prd"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  public_key          = file(pathexpand("~/.ssh/id_rsa.pub"))

  tags = {
    project     = "dbf"
    environment = "prd"
  }
}

resource "azurerm_linux_virtual_machine" "frontend_vm" {
  name                = "vm-web-01-prd"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.frontend_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.ssh_key.public_key
  }

  os_disk {
    name                 = "osdisk-web-01-prd"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  computer_name                   = "vm-web-01-prd"
  disable_password_authentication = true

  tags = {
    project     = "dbf"
    environment = "prd"
    role        = "frontend"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.frontend_subnet_nsg_assoc
  ]
}

resource "azurerm_linux_virtual_machine" "backend_vm" {
  name                = "vm-db-01-prd"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2ats_v2"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.backend_nic.id
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = azurerm_ssh_public_key.ssh_key.public_key
  }

  os_disk {
    name                 = "osdisk-db-01-prd"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  computer_name                   = "vm-db-01-prd"
  disable_password_authentication = true

  tags = {
    project     = "dbf"
    environment = "prd"
    role        = "backend"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.backend_subnet_nsg_assoc
  ]
}

output "frontend_public_ip" {
  value = azurerm_public_ip.frontend_ip.ip_address
}

output "frontend_private_ip" {
  value = azurerm_network_interface.frontend_nic.private_ip_address
}

output "backend_private_ip" {
  value = azurerm_network_interface.backend_nic.private_ip_address
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<-EOT
[frontend]
vm-web-01-prd ansible_host=${azurerm_public_ip.frontend_ip.ip_address} ansible_user=azureuser

[backend]
vm-db-01-prd ansible_host=${azurerm_network_interface.backend_nic.private_ip_address} ansible_user=azureuser ansible_ssh_common_args='-o ProxyJump=azureuser@${azurerm_public_ip.frontend_ip.ip_address}'
EOT
}