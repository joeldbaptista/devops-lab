output "instance_id" {
  description = "Id of the EC2 instance."
  value       = aws_instance.lab.id
}

output "public_ip" {
  description = "Public IPv4 address of the instance."
  value       = aws_instance.lab.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance."
  value       = aws_instance.lab.public_dns
}

output "ssh_user" {
  description = "Default login user of the Amazon Linux 2023 AMI."
  value       = "ec2-user"
}

output "ssh_command" {
  description = "Ready-made SSH command for this instance."
  value       = "ssh -i ${replace(var.public_key_path, ".pub", "")} ec2-user@${aws_instance.lab.public_ip}"
}

output "allowed_ssh_cidr" {
  description = "CIDR that the security group admits on port 22."
  value       = local.ssh_cidr
}
