resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

### Subnets

resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "private subnet 1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "private subnet 2"
  }
}

resource "aws_subnet" "private_subnet3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private subnet 3"
  }
}

resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.10.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet 1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.11.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet 2"
  }
}

resource "aws_subnet" "public_subnet3" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.12.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet 3"
  }
}

### Gateways 

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  region = var.aws_region

  tags = {
    Name = "gateway1"
  }
}

resource "aws_eip" "elastic_IP" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet_gateway]

  tags = {
    Name = "elastic IP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.elastic_IP.id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "NAT gateway"
  }
}

### Route tables
# public route table
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = var.any_ip
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "public route table"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_rtb.id
}

# private route table
resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.main.id


  route {
    cidr_block     = var.any_ip
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private route table"
  }
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_rtb.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_rtb.id
}

resource "aws_route_table_association" "private3" {
  subnet_id      = aws_subnet.private_subnet3.id
  route_table_id = aws_route_table.private_rtb.id
}

### Security groups
# public security group
resource "aws_security_group" "public_sg" {
  name   = "public_sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_rule_pub" {
  security_group_id = aws_security_group.public_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.local_ip
  description       = "SSH from local IP"
}

resource "aws_vpc_security_group_ingress_rule" "http_rule_pub" {
  security_group_id = aws_security_group.public_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = var.any_ip
  description       = "Http from any ip"
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_pub" {
  security_group_id = aws_security_group.public_sg.id
  from_port         = 0
  to_port           = 0
  ip_protocol       = -1
  cidr_ipv4         = var.any_ip
  description       = "Any outgoing traffic"
}

# private security group

resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "Allow inbound traffic only from public security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "Private security group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_rule_prvt" {
  security_group_id            = aws_security_group.private_sg.id
  description                  = "SSH from public SG"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.public_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "app_rule_prvt" {
  security_group_id            = aws_security_group.private_sg.id
  description                  = "App access from public SG"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.public_sg.id
}

resource "aws_vpc_security_group_egress_rule" "egress_rule_prvt" {
  security_group_id = aws_security_group.private_sg.id
  description       = "Allow outbound traffic"
  from_port         = 0
  to_port           = 0
  ip_protocol       = -1
  cidr_ipv4         = var.any_ip
}


# EC2 instance

resource "aws_key_pair" "main" {
    key_name = "aws-ec2-key"
    public_key = file("~/.ssh/aws_ec2_key.pub")
}

resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  region        = var.aws_region
  instance_type = var.ec2_instance_type
  subnet_id = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name = aws_key_pair.main.key_name

    tags = {
      Name = "AWS public ubuntu instance"
    }
}

