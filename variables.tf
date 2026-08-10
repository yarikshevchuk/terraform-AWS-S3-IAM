variable "aws_region" {
  type    = string
  description = "AWS main region"
}

variable "any_ip" {
  type    = string
  description = "Arbitrary ip address range"
}

variable "local_ip" {
  type    = string
  description = "Local IP address in CIDR notation"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type"
}

