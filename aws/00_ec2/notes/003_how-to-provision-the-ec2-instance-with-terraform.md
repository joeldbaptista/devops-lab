# 003 — How to provision the EC2 instance with Terraform

This note records the Terraform configuration under `terraform/` and the
commands that apply it. It assumes the credentials of note 001 work and the key
pair of note 002 exists.

## Decisions

These four decisions are fixed in the configuration:

- The instance joins the **default VPC**, so no networking is created.
- The instance type is **`t4g.micro`**, which is 64-bit ARM (Graviton).
- Port 22 admits **one address only**, the public IP of the machine running
  Terraform.
- The AMI is **Amazon Linux 2023 for arm64**, resolved from an SSM public
  parameter rather than hard-coded, because AWS replaces the image regularly.

The instance type and the AMI architecture must agree. So changing
`instance_type` to an x86 type such as `t3.micro` also requires changing the SSM
parameter name from `al2023-ami-kernel-default-arm64` to
`al2023-ami-kernel-default-x86_64`.

## Files

```sh
terraform/versions.tf    # Terraform and provider versions, provider config, default tags
terraform/variables.tf   # every input, all with defaults
terraform/main.tf        # data sources and the five resources
terraform/outputs.tf     # instance id, addresses, ready-made SSH command
terraform/.gitignore     # state, .terraform/, tfvars
```

`.terraform.lock.hcl` is **not** ignored, because committing it pins the
provider versions for later runs.

## Resources created

Five resources, and this list is complete:

1. `aws_key_pair.lab` — imports `~/.ssh/devops-lab-ec2.pub`.
2. `aws_security_group.lab` — an empty group in the default VPC.
3. `aws_vpc_security_group_ingress_rule.ssh` — TCP 22 from the operator address.
4. `aws_vpc_security_group_egress_rule.all` — all outbound traffic, which the
   instance needs in order to install packages.
5. `aws_instance.lab` — the instance itself, with a public IP, an 8 GiB
   encrypted gp3 root volume, and IMDSv2 required.

The rules are separate resources rather than inline `ingress` and `egress`
blocks, because the inline form makes the provider fight any out-of-band change
to the group.

## How the operator IP is resolved

The variable `allowed_ssh_cidr` defaults to `null`. While it stays `null`,
Terraform reads `https://checkip.amazonaws.com` through the `http` provider and
allows that address with a `/32` mask. Setting the variable pins the CIDR
instead and skips the lookup.

One consequence: a changed public IP produces a diff on the ingress rule, and
the fix is another `terraform apply`. Home connections change address, so expect
this.

Note 004 records how to find the address by hand, and how to pin it.

## Commands

```sh
cd terraform
terraform init          # once, and again after changing provider versions
terraform fmt           # rewrite the files in canonical style
terraform validate      # syntax and type checks, no AWS calls
terraform plan          # read-only, shows what apply would do
terraform apply         # creates the resources, asks for confirmation
terraform output        # re-prints the outputs later
terraform destroy       # removes everything this configuration created
```

## Verified on 2026-09-14

`terraform init` installed `hashicorp/aws` v6.64.0 and `hashicorp/http` v3.6.2.
`terraform validate` passed. `terraform plan` reported `5 to add, 0 to change, 0
to destroy` and resolved these values:

- AMI `ami-0c8fa3e43097681d9`
- Instance type `t4g.micro`
- Subnet `subnet-06f4481ae7a15eb1f` in `eu-west-1a`, chosen as the first subnet
  id in sorted order so that a re-plan does not move the instance
- VPC `vpc-03ad94ff35fbeecf7`
- Ingress CIDR `85.245.154.57/32`

`terraform apply` had not been run when this note was written, so no AWS
resources existed yet.

## Cost

`t4g.micro` and an 8 GiB gp3 volume are small, but they are not free outside the
free tier allowance. So run `terraform destroy` when the lab is idle.

## Next

Install Docker with Ansible. Ansible is not yet installed on this machine, so
that step begins with installing it.
