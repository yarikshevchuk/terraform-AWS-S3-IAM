output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

output "s3_main_bucket_name" {
  description = "Auto generated name of the main S3 bucket"
  value       = aws_s3_bucket.main_s3.arn
}

output "s3_replication_bucket_name" {
  description = "Auto generated name of the replication S3 bucket"
  value       = aws_s3_bucket.replication_s3.arn
}
