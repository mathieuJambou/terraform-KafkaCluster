# Configure the Microsoft Azure Provider
provider "azurerm" {
    features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "terraformgroup" {
    name     = "Kafka-rg"
    location = "eastus"

    tags = {
        environment = "Kafka"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "terraformnetwork" {
    name                = "Vnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.terraformgroup.name

    tags = {
        environment = "Kafka"
    }
}

# Create subnet
resource "azurerm_subnet" "terraformsubnet" {
    name                 = "Subnet"
    resource_group_name  = azurerm_resource_group.terraformgroup.name
    virtual_network_name = azurerm_virtual_network.terraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "terraformpublicip" {
	count = 4
	
    name                         = "PublicIP.${count.index}"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.terraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Kafka"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraformnsg" {
    name                = "NetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.terraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "zookeeper"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "2181"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "2888"
        priority                   = 1051
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "2888"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "3888"
        priority                   = 1052
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3888"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "tools_8001"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8001"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	security_rule {
        name                       = "tools_9001"
        priority                   = 1004
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9001"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	
	
	security_rule {
        name                       = "9092"
        priority                   = 1100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "9092"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
	

    tags = {
        environment = "Kafka"
    }
}

# Create network interface
resource "azurerm_network_interface" "terraformnic" {
	count = 4
	
	name                      = "NIC.${count.index}"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.terraformgroup.name

    ip_configuration {
        name                          = "NicConfiguration.${count.index}"
        subnet_id                     = azurerm_subnet.terraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.terraformpublicip[count.index].id
    }

    tags = {
        environment = "Kafka"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
	count = 4
	
    network_interface_id      = azurerm_network_interface.terraformnic[count.index].id
    network_security_group_id = azurerm_network_security_group.terraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.terraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.terraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Kafka"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

# Create virtual machine
resource "azurerm_linux_virtual_machine" "terraformvm" {
	count = 4
	
    name                  = "VM.${count.index}"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.terraformgroup.name
    network_interface_ids = [azurerm_network_interface.terraformnic[count.index].id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "OsDisk.${count.index}"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "vm.${count.index}"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Kafka"
    }
}


resource "null_resource" "vm_provisioner" {
  count = 4
  depends_on = [azurerm_public_ip.terraformpublicip, azurerm_linux_virtual_machine.terraformvm]
  
  
  
  
  provisioner "remote-exec" {
	connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	inline = [
	  "echo '${azurerm_network_interface.terraformnic[0].private_ip_address} kafka1 \n${azurerm_network_interface.terraformnic[0].private_ip_address} zookeeper1 \n${azurerm_network_interface.terraformnic[1].private_ip_address} kafka2 \n${azurerm_network_interface.terraformnic[1].private_ip_address} zookeeper2 \n${azurerm_network_interface.terraformnic[2].private_ip_address} kafka3 \n${azurerm_network_interface.terraformnic[2].private_ip_address} zookeeper3' | sudo tee --append /etc/hosts",
    ]
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "init.sh"
    destination = "/home/azureuser/init.sh"
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "zookeeper"
    destination = "~/zookeeper"
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "kafka"
    destination = "~/kafka_service"
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "zookeeper.properties"
    destination = "~/zookeeper.properties"
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "server.properties"
    destination = "~/server.properties"
  }

  provisioner "remote-exec" {
  
   connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[count.index].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    inline = [
      "chmod +x /home/azureuser/init.sh",
      "/home/azureuser/init.sh",
	  "sudo mv ~/zookeeper.properties /home/azureuser/kafka/config/zookeeper.properties",
	  "sudo chown azureuser:azureuser /home/azureuser/kafka/config/zookeeper.properties",
	  "sudo chmod 655 /home/azureuser/kafka/config/zookeeper.properties",
	  "echo '${count.index + 1}' | sudo tee /tmp/zookeeper/myid",
	  "sudo mv ~/zookeeper_service /etc/init.d/zookeeper",
      "sudo chmod +x /etc/init.d/zookeeper",
      "sudo chown root:root /etc/init.d/zookeeper",
      "sudo update-rc.d zookeeper defaults",
      "sudo service zookeeper restart",
      "echo 'ruok' | nc localhost 2181 ; echo",
#     "cat kafka/logs/zookeeper.out",
      "sudo mkdir /data/kafka",
      "sudo chown -R azureuser:azureuser /tmp/kafka",
	  "sudo mv ~/zookeeper.properties /home/azureuser/kafka/config/server.properties",
	  "sudo chown azureuser:azureuser /home/azureuser/kafka/config/server.properties",
	  "sed -i 's/BROKERID/${count.index + 1}/' /home/azureuser/kafka/config/server.properties",
	  "sudo mv ~/kafka_service /etc/init.d/kafka",
      "sudo chmod +x /etc/init.d/kafka",
      "sudo chown root:root /etc/init.d/kafka",
      "sudo update-rc.d kafka defaults",
	  "sudo service kafka restart",
    ]
  }
  
}

resource "null_resource" "tools_provisioner" {
  depends_on = [azurerm_public_ip.terraformpublicip, azurerm_linux_virtual_machine.terraformvm]
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[3].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "init-tools.sh"
    destination = "/home/azureuser/init-tools.sh"
	
  }
  
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[3].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "kafka-manager-docker-compose.yml"
    destination = "/home/azureuser/kafka-manager-docker-compose.yml"
	
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[3].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "kafka-topics-ui-docker-compose.yml"
    destination = "/home/azureuser/kafka-topics-ui-docker-compose.yml"
	
  }
  
  provisioner "file" {
  
    connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[3].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    source      = "zoonavigator-docker-compose.yml"
    destination = "/home/azureuser/zoonavigator-docker-compose.yml"
	
  }
  
 provisioner "remote-exec" {
  
   connection {
      type     		= "ssh"
	  user			= "azureuser"
      host     		= azurerm_public_ip.terraformpublicip[3].ip_address
      private_key   = tls_private_key.example_ssh.private_key_pem
    }
	
    inline = [
      "chmod +x /home/azureuser/init-tools.sh",
      "/home/azureuser/init-tools.sh",
	  "docker run hello-world",
	  "docker-compose -f zoonavigator-docker-compose.yml up -d",
#     "docker-compose -f kafka-manager-docker-compose.yml up -d",
#     "docker-compose -f kafka-topics-ui-docker-compose.yml up -d",
    ]
  }  
}