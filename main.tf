### AWS VPC

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
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

resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.10.0/24"

  map_public_ip_on_launch = true

  tags = {
    Name = "public subnet 1"
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

### Security groups
# public security group
resource "aws_security_group" "public_sg" {
  name   = "public_sg"
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public security group"
  }
}

# public security group rules
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

# private security group rules
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
  ip_protocol       = -1
  cidr_ipv4         = var.any_ip
}


# EC2 instance

resource "aws_key_pair" "main" {
  key_name   = "aws-ec2-key"
  public_key = file("~/.ssh/aws_ec2_key.pub")
}

resource "aws_instance" "main" {
  ami                    = data.aws_ami.ubuntu.id
  region                 = var.aws_region
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public_subnet1.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = aws_key_pair.main.key_name

  user_data_base64 = filebase64("${path.module}/user-data.sh")

  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  tags = {
    Name = "AWS public ubuntu instance"
  }
}

### Utility: Random prefix

resource "random_bytes" "bucket_prefix" {
  length = 16
}

### S3 bucket 

resource "aws_s3_bucket" "main_s3" {
  bucket        = "${random_bytes.bucket_prefix.hex}-main-s3-bucket"
  force_destroy = true

  tags = {
    Name = "Main S3 bucket"
  }
}

resource "aws_s3_bucket" "replication_s3" {
  bucket        = "${random_bytes.bucket_prefix.hex}-replication-s3-bucket"
  force_destroy = true

  tags = {
    Name = "Main bucket replication"
  }
}

# bucket versioning

resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.main_s3.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "replication" {
  bucket = aws_s3_bucket.replication_s3.id

  versioning_configuration {
    status = "Enabled"
  }
}


# S3 bucket policy

resource "aws_s3_bucket_policy" "main_s3_policy" {
  bucket = aws_s3_bucket.main_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2RoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_s3_role.arn
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.main_s3.arn,
          "${aws_s3_bucket.main_s3.arn}/*"
        ]
      },
      {
        Sid       = "DenyAllExceptRoleAndAdmin"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main_s3.arn,
          "${aws_s3_bucket.main_s3.arn}/*"
        ]
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = [
              aws_iam_role.ec2_s3_role.arn,
              "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.ec2_s3_role.name}/*",

              aws_iam_role.s3_replication_role.arn,
              "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.s3_replication_role.name}/*",

              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
              data.aws_caller_identity.current.arn
            ]
          }
        }
      }
    ]
  })
}

### IAM roles

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

resource "aws_iam_role" "s3_replication_role" {
  name = "s3-bucket-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# Custom policy
resource "aws_iam_policy" "s3_buckets_policy" {
  name        = "ec2-s3-access-role"
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
          aws_s3_bucket.replication_s3.arn
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
          "${aws_s3_bucket.replication_s3.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name = "EC2 S3 Role"
  }
}

resource "aws_iam_policy" "replication_policy" {
  name = "s3-bucket-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.main_s3.arn]
      },
      {
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.main_s3.arn}/*"]
      },
      {
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.replication_s3.arn}/*"]
      }
    ]
  })
}

# Attaching policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_buckets_policy.arn
}

resource "aws_iam_role_policy_attachment" "s3_replication_attachment" {
  role       = aws_iam_role.s3_replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
}

# Static webpage

resource "aws_s3_bucket_website_configuration" "mains_s3_website" {
  bucket = aws_s3_bucket.main_s3.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.main_s3.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"

  depends_on = [aws_s3_bucket_website_configuration.mains_s3_website]
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [
    aws_s3_bucket_versioning.source,
    aws_s3_bucket_versioning.replication,
    aws_iam_role_policy_attachment.s3_access_attachment,
    aws_iam_role_policy_attachment.s3_replication_attachment
  ]

  role   = aws_iam_role.s3_replication_role.arn
  bucket = aws_s3_bucket.main_s3.id

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replication_s3.arn
      storage_class = "STANDARD"
    }
  }
}
