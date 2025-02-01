## Create a SSH keypair
To start, use the command ssh-keygen -t rsa -b 4096 -C "your_email@example_email.com" to generate a new key pair. 

## Update Cloud-config.yaml
Open ``scripts/cloud-config.yaml`` to define the public key to use when connecting as well as what packages to install.

Underneath the section labeled ssh-authorized-keys, add the contents of the public key. 

Add a new section named "packages" with nginx and nmap to install these packages on the host.

The updated config should look like this:

```
#cloud-config
users:
  - name: web
    primary_group: web
    groups: wheel
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh-authorized-keys:
      - ssh-ed25519 public_key_here user@host

packages:
  - nginx
  - nmap
```
## Initialize Terraform directory

Initialize your Terraform directory with ``terraform init``

## Add necesseray values to main.tf
Our main.tf file will have to have some values filled in to work and create our VPC. 
In our aws_vpc web resource we need to enable DNS support by adding the lines:

```
	enable_dns_support = true
	enable_dns_hostnames = true
```

In the tags block, we need to add:
```
	Name = "project_vpc"
	Project = local.project_name 
```

This will need to be repeated for every resource block we edit.

Our aws_subnet resource needs an availability zone as well as the option to enable public IPs for instances launched. 

```
	availability_zone = "us-west-2a"
	map_public_ip_on_launch = true
```

As well as the project tag:

```
Project = local.project_name
```

Our aws_internet_gateway resource needs the vpc_id added, to associate the gateway resource with the VPC resource:

```
	vpc_id = aws_vpc.web.id
```

As well as the project name in the tags:

```
	Project = local.project_name
```

Similarly, the aws_route_table resource requires the vpc_id association:

```
	vpc_id = aws_vpc.web.id
```

and the project name in the tags:
```
	Project = local.project_name
```

Our aws_route resource needs the gateway_id associated:

```
	gateway_id = aws_internet_gateway.web-gw.d
```

Our aws_route_table_association resource needs the id of the created subnet associated. 

```
	subnet_id = aws_subnet.web.id
```

Our aws_security_group resource needs to have the security group attached to the vpc. 

```
	vpc_id = aws_vpc.web.id
```

as well as the project tag

```
	Project = local.project_name
```


Our aws_vpc_security_group_ingress_rule resources requires some missing variables. 

```
	security_group_id = aws_security_group.web.id
	# Allow inbound TCP traffic over port 22 from anywhere
	cidr_ipv4    = "0.0.0.0/0"
	from_port    = 22
	ip_protocol  "tcp"
	to_port      = 22
```


```
	security_group_id = aws_security_group.web.id
	# Allow inbound HTTP traffic over port 80 from anywhere
	cidr_ipv4   = "0.0.0.0/0"
	from_port   = 80
	ip_protocol = "tcp"
	to_port     = 80
```

```
resource "aws_vpc_security_group_egress_rule" "web-egress" {
	security_group_id = aws_security_group.web.id
	# Allow outbound traffic to any destination over any port/protocol
	cidr_ipv4    = "0.0.0.0/0"
	ip_protocol  = "-1"
}
```

Our aws_instace resource requires some variables that specify how our instance will be created to be set before creation:

```
resource "aws_instance" "web" {
  # Use the AMI defined in the data block
  ami = data.aws_ami.ubuntu.id
  # Assign instance type t2.micro
  instance_type = "t2.micro"
  # Pull user data from scripts/cloud-config.yaml 
  user_data = file("scripts/cloud-config.yaml")
  # Assign the web security group to this VM
  vpc_security_group_ids = [aws_security_group.web.id]
  # Connect it to the web subnet
  subnet_id = aws_subnet.web.id

  tags = {
    Name    = "Web"
    Project = local.project_name
  }
}
```

----

## Using Terraform to boot the VM

The first step is to format the main.tf. Not strictly necessary, but good practice

``terraform fmt main.tf``

Next, validate the Terraform config:

``terraform validate```

Next, create a Terraform plan:

``terraform plan -o main.tfout``

Finally, apply and run that plan:

``terraform apply main.tfout``


Then, it will run the Terraform plan and output the connection details for the new VM. You can connect to it using SSH:

``ssh -i path/to/key web@ip_address``
