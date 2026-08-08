data "aws_ami" "ubuntu" {
  most_recent = true
  region      = var.aws_region

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["amazon"]
}

# Fetch AWS account ID
data "aws_caller_identity" "current" {}