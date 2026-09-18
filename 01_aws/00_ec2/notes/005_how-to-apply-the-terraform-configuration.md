# 005 — How to apply the Terraform configuration

This note records the apply that created the instance described in note 003, and
how to confirm the result.

## Apply

```sh
cd terraform
terraform apply
```

Terraform prints the plan and waits for `yes`. The `-auto-approve` flag skips
that confirmation, and it is not worth using here, because the confirmation is
the only guard against an unintended change.

`terraform init` is not repeated before each apply. It is needed only after a
fresh clone, after a provider version change, or when Terraform asks for it.

## Confirm

```sh
terraform output
```

```sh
ssh -i ~/.ssh/devops-lab-ec2 \
    -o StrictHostKeyChecking=accept-new \
    ec2-user@"$(terraform output -raw public_ip)" \
    'head -2 /etc/os-release; uname -m'
```

Expect `Amazon Linux 2023` and the architecture `aarch64`, which confirms the
arm64 AMI matched the `t4g.micro` instance type.

An SSH attempt that hangs rather than failing points at the security group, not
at the instance. Note 004 holds the two commands that compare your current
address against the admitted CIDR.

## Result on 2026-09-14

Five resources created. State holds nine entries, the five resources plus four
data sources:

```
data.aws_ssm_parameter.al2023
data.aws_subnets.default
data.aws_vpc.default
data.http.my_ip[0]
aws_instance.lab
aws_key_pair.lab
aws_security_group.lab
aws_vpc_security_group_egress_rule.all
aws_vpc_security_group_ingress_rule.ssh
```

Outputs:

```
allowed_ssh_cidr = "85.245.154.57/32"
instance_id      = "i-0509b70c01d60d18f"
public_dns       = "ec2-34-243-130-76.eu-west-1.compute.amazonaws.com"
public_ip        = "34.243.130.76"
ssh_command      = "ssh -i ~/.ssh/devops-lab-ec2 ec2-user@34.243.130.76"
ssh_user         = "ec2-user"
```

The instance runs as `t4g.micro` in `eu-west-1a`. SSH worked and the instance is
visible in the AWS console.

Read the same facts back from AWS rather than from state with:

```sh
aws ec2 describe-instances \
  --filters Name=tag:Project,Values=devops-lab-ec2 \
            Name=instance-state-name,Values=running,pending,stopped \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Type:InstanceType,Ip:PublicIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table
```

## State

The state file is `terraform/terraform.tfstate`, it is local, and it is
gitignored. So deleting it would leave the AWS resources running with nothing
tracking them, and they would then have to be removed by hand in the console.

## Next

Destroy the resources when the lab is idle. See
`006_how-to-destroy-the-instance.md`.
