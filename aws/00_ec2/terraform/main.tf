# The public IP of the machine running Terraform, used when the caller does not
# pin allowed_ssh_cidr explicitly.
data "http" "my_ip" {
  count = var.allowed_ssh_cidr == null ? 1 : 0
  url   = "https://checkip.amazonaws.com"
}

# Latest Amazon Linux 2023 AMI for 64-bit ARM, resolved at plan time. The AMI id
# changes whenever AWS publishes a new image, so it is never hard-coded.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  ssh_cidr = coalesce(
    var.allowed_ssh_cidr,
    try("${chomp(data.http.my_ip[0].response_body)}/32", null),
  )

  # Pick one subnet deterministically, so a re-plan does not move the instance.
  subnet_id = sort(data.aws_subnets.default.ids)[0]
}

resource "aws_key_pair" "lab" {
  key_name   = var.project
  public_key = file(pathexpand(var.public_key_path))
}

resource "aws_security_group" "lab" {
  name        = "${var.project}-sg"
  description = "SSH from one address in, everything out."
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.project}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.lab.id
  description       = "SSH from the operator address only."
  cidr_ipv4         = local.ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.lab.id
  description       = "All outbound traffic, needed to install packages."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "lab" {
  # The SSM parameter value is marked sensitive, which would hide the AMI id from
  # every plan. The id is public information, so unmask it.
  ami           = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type = var.instance_type
  subnet_id     = local.subnet_id
  key_name      = aws_key_pair.lab.key_name

  vpc_security_group_ids      = [aws_security_group.lab.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  # Require IMDSv2, so the instance metadata service refuses unauthenticated
  # requests.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = var.project
  }
}
