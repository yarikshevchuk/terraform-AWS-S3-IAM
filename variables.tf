variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "aws_backup_region" {
  type    = string
  default = "us-east-2"
}

variable "any_ip" {
  type    = string
  default = "0.0.0.0/0"
}

variable "local_ip" {
  type    = string
  default = "193.239.234.196/32"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "ec2_disk_size" {
  type    = number
  default = 20
}





