terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.73.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "${var.system_name}-${var.stage}-rg"
  location = var.location
}

module "network" {
  source              = "Azure/network/azurerm"
  resource_group_name = azurerm_resource_group.this.name
  vnet_name           = "${var.system_name}-${var.stage}-vnet"
  address_space       = "10.0.0.0/16"
  subnet_prefixes     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_names        = ["subnet1", "subnet2", "subnet3"]

  subnet_enforce_private_link_endpoint_network_policies = {}

  subnet_service_endpoints = {}

  tags = {
    "Name"  = var.system_name
    "Stage" = var.stage
  }

  depends_on = [
    azurerm_resource_group.this,
  ]
}

data "template_file" "script1" {
  template = file("${path.module}/cloud-init1.yml")
}

data "template_file" "script2" {
  template = file("${path.module}/cloud-init2.yml")
}

data "template_cloudinit_config" "config1" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.script1.rendered
  }
}

data "template_cloudinit_config" "config2" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.script2.rendered
  }
}

module "server1" {
  source                           = "Azure/compute/azurerm"
  resource_group_name              = azurerm_resource_group.this.name
  vm_hostname                      = "server1"
  nb_public_ip                     = 0
  remote_port                      = "22"
  vm_os_publisher                  = "Canonical"
  vm_os_offer                      = "UbuntuServer"
  vm_os_sku                        = "18.04-LTS"
  vnet_subnet_id                   = module.network.vnet_subnets[0]
  delete_os_disk_on_termination    = true
  nb_data_disk                     = 0
  data_sa_type                     = "Standard_LRS"
  enable_ssh_key                   = true
  ssh_key_values                   = [file(var.ssh_key_path)]
  vm_size                          = var.virtual_machine_size
  delete_data_disks_on_termination = true
  custom_data                      = data.template_cloudinit_config.config1.rendered

  tags = {
    "Name"  = var.system_name
    "Stage" = var.stage
  }

  depends_on = [
    azurerm_resource_group.this,
    module.network,
  ]
}

module "server2" {
  source                           = "Azure/compute/azurerm"
  resource_group_name              = azurerm_resource_group.this.name
  vm_hostname                      = "server2"
  nb_public_ip                     = 0
  remote_port                      = "22"
  vm_os_publisher                  = "Canonical"
  vm_os_offer                      = "UbuntuServer"
  vm_os_sku                        = "18.04-LTS"
  vnet_subnet_id                   = module.network.vnet_subnets[0]
  delete_os_disk_on_termination    = true
  nb_data_disk                     = 0
  data_sa_type                     = "Standard_LRS"
  enable_ssh_key                   = true
  ssh_key_values                   = [file(var.ssh_key_path)]
  vm_size                          = var.virtual_machine_size
  delete_data_disks_on_termination = true
  custom_data                      = data.template_cloudinit_config.config2.rendered

  tags = {
    "Name"  = var.system_name
    "Stage" = var.stage
  }

  depends_on = [
    azurerm_resource_group.this,
    module.network,
  ]
}

module "bastion" {
  source                           = "Azure/compute/azurerm"
  resource_group_name              = azurerm_resource_group.this.name
  vm_hostname                      = "bastion"
  nb_public_ip                     = 1
  remote_port                      = "22"
  vm_os_publisher                  = "Canonical"
  vm_os_offer                      = "UbuntuServer"
  vm_os_sku                        = "18.04-LTS"
  vnet_subnet_id                   = module.network.vnet_subnets[1]
  delete_os_disk_on_termination    = true
  nb_data_disk                     = 0
  data_sa_type                     = "Standard_LRS"
  enable_ssh_key                   = true
  ssh_key_values                   = [file(var.ssh_key_path)]
  vm_size                          = var.virtual_machine_size
  delete_data_disks_on_termination = true

  tags = {
    "Name"  = var.system_name
    "Stage" = var.stage
  }

  depends_on = [
    azurerm_resource_group.this,
    module.network,
  ]
}

module "loadbalancer" {
  source                                 = "Azure/loadbalancer/azurerm"
  resource_group_name                    = azurerm_resource_group.this.name
  name                                   = "${var.system_name}-${var.stage}-lb"
  type                                   = "private"
  frontend_subnet_id                     = module.network.vnet_subnets[2]
  frontend_private_ip_address_allocation = "Static"
  frontend_private_ip_address            = "10.0.3.6"
  lb_sku                                 = "Standard"

  remote_port = {
    ssh = ["Tcp", "22"]
  }

  lb_port = {
    http  = ["80", "Tcp", "80"]
    https = ["443", "Tcp", "443"]
  }

  lb_probe = {
    http  = ["Tcp", "80", ""]
    http2 = ["Http", "1443", "/"]
  }

  tags = {
    "Name"  = var.system_name,
    "Stage" = var.stage
  }

  depends_on = [
    azurerm_resource_group.this,
    module.network,
  ]
}

resource "azurerm_lb_backend_address_pool_address" "address1" {
  name                    = "${var.system_name}-${var.stage}-lb_address_pool_server1"
  backend_address_pool_id = module.loadbalancer.azurerm_lb_backend_address_pool_id
  virtual_network_id      = module.network.vnet_id
  ip_address              = module.server1.network_interface_private_ip[0]
}

resource "azurerm_lb_backend_address_pool_address" "address2" {
  name                    = "${var.system_name}-${var.stage}-lb_address_pool_server2"
  backend_address_pool_id = module.loadbalancer.azurerm_lb_backend_address_pool_id
  virtual_network_id      = module.network.vnet_id
  ip_address              = module.server2.network_interface_private_ip[0]
}
