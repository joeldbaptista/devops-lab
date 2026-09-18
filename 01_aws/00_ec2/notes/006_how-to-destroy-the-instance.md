# 006 — How to destroy the instance

`t4g.micro` and its 8 GiB volume are cheap but not free outside the free tier
allowance, so destroy the lab whenever it is idle.

## Destroy

```sh
cd terraform
terraform destroy
```

Terraform lists what it will remove and waits for `yes`.

## What goes, and what stays

Removed, and this list is complete:

1. `aws_instance.lab` — the instance and its root volume, because the volume is
    set to delete on termination.
2. `aws_vpc_security_group_ingress_rule.ssh`
3. `aws_vpc_security_group_egress_rule.all`
4. `aws_security_group.lab`
5. `aws_key_pair.lab` — the public key held by AWS.

Untouched, and this list is also complete:

- `~/.ssh/devops-lab-ec2` and `~/.ssh/devops-lab-ec2.pub`, because Terraform
  never created them. So a later apply imports the same key again and no new
  key generation is needed.
- The default VPC and its subnets, because the configuration only reads them
  through data sources.

## Confirm the account is clean

```sh
aws ec2 describe-instances \
  --filters Name=tag:Project,Values=devops-lab-ec2 \
            Name=instance-state-name,Values=running,pending,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text

aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text
```

Both should print nothing. An instance in state `shutting-down` or `terminated`
is expected for a short while and costs nothing.

## Rebuilding afterwards

`terraform apply` recreates everything. Two differences to expect:

- The public IP changes, because the configuration uses no Elastic IP. So the
  `public_ip`, `public_dns`, and `ssh_command` outputs all change.
- The new instance presents a new SSH host key, and then SSH refuses to connect
  and warns about `~/.ssh/known_hosts`. Clear the stale entry:

```sh
ssh-keygen -R 34.243.130.76
```

Any Ansible inventory or Docker deployment step that records the address must be
refreshed after a rebuild, because of the changed IP.

## Cheaper than destroying

Stopping the instance keeps it and its data but stops the instance-hour charges,
although the EBS volume is still billed:

```sh
aws ec2 stop-instances  --instance-ids "$(terraform output -raw instance_id)"
aws ec2 start-instances --instance-ids "$(terraform output -raw instance_id)"
```

One caveat: a stop and start assigns a new public IP as well, so the same
known_hosts and inventory refresh applies. And Terraform does not track the
stopped state, so a later `terraform apply` leaves the instance stopped.

## If the state file is lost

`terraform destroy` cannot act without `terraform/terraform.tfstate`. Then delete
the resources by hand, in this order, because a security group in use cannot be
deleted:

1. Terminate the instance in the EC2 console, and wait for `terminated`.
2. Delete the security group `devops-lab-ec2-sg`.
3. Delete the key pair `devops-lab-ec2`.

## Next

Install Docker with Ansible. Do that before destroying, or rebuild first.
