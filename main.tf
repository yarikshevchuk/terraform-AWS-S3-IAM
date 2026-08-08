### AWS VPC

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_vpc_endpoint" "s3" {
    vpc_id = aws_vpc.main.id
    service_name = "com.amazonaws.eu-central-1.s3"

    route_table_ids = [
        aws_route_table.public_rtb.id,
        aws_route_table.private_rtb.id
    ]

    tags = {
        Name = "AWS vpc endpoint for S3"
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

### S3 bucket 

resource "aws_s3_bucket" "main_s3" {
  bucket = "main-s3-bucket"
  
  tags = {
    Name = "Main S3 bucket"
  }
}

resource "aws_s3_bucket" "backup_s3" {
  bucket = "backup-s3-bucket"

  tags = {
    Name = "Main bucket backup"
  }
}

# bucket versioning

resource "aws_s3_bucket_versioning" "vers1" {
  bucket = aws_s3_bucket.main_s3.id

  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role 

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2 S3 role"
  }
}

# Custom policy
resource "aws_iam_policy" "s3_buckets_policy" {
  name = "ec2-s3-access-role"
  description = "IAM policy with read/write access restricted to specific buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.main_s3.arn,
          aws_s3_bucket.backup_s3.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.main_s3.arn}/*",
          "${aws_s3_bucket.backup_s3.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "EC2 S3 Role"
  }
}

# Attaching policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_buckets_policy.arn
}



