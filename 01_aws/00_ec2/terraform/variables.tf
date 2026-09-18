variable "region" {
  description = "AWS region that holds the instance."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name prefix and Project tag applied to every resource."
  type        = string
  default     = "devops-lab-ec2"
}

variable "instance_type" {
  description = "EC2 instance type. Must match the architecture of the AMI."
  type        = string
  default     = "t4g.micro"
}

variable "public_key_path" {
  description = "Path to the SSH public key imported as the EC2 key pair."
  type        = string
  default     = "~/.ssh/devops-lab-ec2.pub"
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    CIDR allowed to reach port 22. Leave null to detect the public IP of the
    machine running Terraform and allow that address only.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.allowed_ssh_cidr == null || can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid CIDR block, for example 203.0.113.4/32."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GiB."
  type        = number
  default     = 8
}
