# 007 — How to check EC2 instances with the AWS CLI

This note records the read-only AWS CLI commands that inspect the instance. None
of them changes anything, so all of them are safe to run at any time. They serve
two purposes: confirming that Terraform produced what was intended, and
diagnosing a failed SSH attempt.

Every command below assumes the credentials of note 001 and the region
`eu-west-1` from `~/.aws/config`.

The instance `i-0509b70c01d60d18f` was destroyed on 2026-09-13 at 23:34 GMT, so
every id and address recorded below is a historical example. The output shown
was captured while the instance ran, and it is accurate for that moment.
Substitute the ids of a current instance when running these commands.

## Two flags that shape every command

- `--query` takes a JMESPath expression and selects fields out of the raw JSON.
  Without it the output of `describe-instances` runs to hundreds of lines.
- `--output` takes `json`, `table`, or `text`. Use `table` when reading with your
  eyes and `text` when feeding a shell variable.

A `--query` expression that builds an object, written `{Label:Path,...}`, renames
the fields. A bare list, written `[Path,Path]`, keeps the order but loses the
labels.

## 1. List the instances

```sh
aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{Id:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,State:State.Name,Type:InstanceType,Ip:PublicIpAddress}' \
  --output table
```

Observed on 2026-09-14: `i-0509b70c01d60d18f`, name `devops-lab-ec2`, state
`running`, type `t4g.micro`, IP `34.243.130.76`.

The nesting `Reservations[].Instances[]` is not optional. AWS groups instances
into reservations, so a query that starts at `Instances[]` returns nothing.

Extracting the `Name` tag needs the filter `Tags[?Key==`Name`]|[0].Value`,
because tags arrive as an unordered list of key and value pairs rather than as
an object.

## 2. Narrow the list with filters

`--filters` runs server-side and `--query` runs client-side, so prefer filters
when the account holds many instances.

```sh
aws ec2 describe-instances \
  --filters Name=tag:Project,Values=devops-lab-ec2 \
            Name=instance-state-name,Values=running,pending,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text
```

Filtering on state matters, because a terminated instance stays visible for
about an hour. So an unfiltered list can show instances that no longer exist.

Useful filter names, a partial list: `tag:<Key>`, `instance-state-name`,
`instance-type`, `availability-zone`, `vpc-id`, `image-id`, `ip-address`.

## 3. Check the health of an instance

```sh
aws ec2 describe-instance-status --instance-ids i-0509b70c01d60d18f \
  --query 'InstanceStatuses[].{Id:InstanceId,Instance:InstanceStatus.Status,System:SystemStatus.Status,State:InstanceState.Name}' \
  --output table
```

Observed: state `running`, instance status `ok`, system status `ok`.

The two statuses differ. The system status covers the AWS hardware and network
beneath the instance, and the instance status covers the guest operating system.
Both reach `ok` a minute or two after launch, so `initializing` right after an
apply is expected rather than a fault.

This command hides instances that are not running unless you add
`--include-all-instances`, and that behaviour surprises people.

## 4. Wait instead of polling

```sh
aws ec2 wait instance-running   --instance-ids i-0509b70c01d60d18f
aws ec2 wait instance-status-ok --instance-ids i-0509b70c01d60d18f
```

Each command blocks until the condition holds, then exits 0. So they belong in
scripts, ahead of the first SSH attempt. `instance-status-ok` is the stronger
condition, because `running` only means the hypervisor started the instance.

## 5. Inspect the security group

Use this when SSH hangs. A hang means the packets are dropped, and a security
group is the usual cause.

```sh
aws ec2 describe-instances --instance-ids i-0509b70c01d60d18f \
  --query 'Reservations[].Instances[].SecurityGroups' --output table

aws ec2 describe-security-group-rules \
  --filters Name=group-id,Values=sg-0bec1f80ba0cc8ccd \
  --query 'SecurityGroupRules[].{Id:SecurityGroupRuleId,Egress:IsEgress,Proto:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4}' \
  --output table
```

Observed: group `sg-0bec1f80ba0cc8ccd` named `devops-lab-ec2-sg`, holding exactly
two rules:

```
85.245.154.57/32  ingress  tcp  22 -> 22
0.0.0.0/0         egress   -1   all
```

Compare that ingress CIDR against your current address from note 004. A mismatch
explains the hang.

## 6. Inspect the disk

```sh
aws ec2 describe-volumes \
  --filters Name=attachment.instance-id,Values=i-0509b70c01d60d18f \
  --query 'Volumes[].{Id:VolumeId,Size:Size,Type:VolumeType,Enc:Encrypted,State:State,Device:Attachments[0].Device,DeleteOnTerm:Attachments[0].DeleteOnTermination}' \
  --output table
```

Observed: `vol-085b2776deab20d5c`, 8 GiB, `gp3`, encrypted, `in-use`, attached at
`/dev/xvda`, and delete-on-termination `True`. So `terraform destroy` takes the
volume with the instance and leaves nothing billable behind.

## 7. Confirm the image and the instance type agree

```sh
aws ec2 describe-images --image-ids ami-0c8fa3e43097681d9 \
  --query 'Images[].{Id:ImageId,Name:Name,Arch:Architecture,Created:CreationDate}' --output table

aws ec2 describe-instance-types --instance-types t4g.micro \
  --query 'InstanceTypes[].{Type:InstanceType,Arch:ProcessorInfo.SupportedArchitectures[0],vCPU:VCpuInfo.DefaultVCpus,MemMiB:MemoryInfo.SizeInMiB}' --output table
```

Observed: AMI `al2023-ami-2023.12.20260909.0-kernel-6.18-arm64`, architecture
`arm64`, created 2026-09-09. Instance type `t4g.micro`, architecture `arm64`,
2 vCPU, 1024 MiB.

Both report `arm64`, which is the agreement note 003 requires. A mismatch here
makes the launch fail outright rather than boot into a broken state.

The AMI creation date shows how fresh the image is. AWS republishes the image
regularly, so the id behind the SSM parameter changes and a later apply may
replace the instance.

## 8. Read the boot log

```sh
aws ec2 get-console-output --instance-id i-0509b70c01d60d18f --latest \
  --output text --query Output | tail -20
```

Observed tail: `Amazon Linux 2023.12.20260909` and
`Kernel 6.18.44-99.149.amzn2023.aarch64 on an aarch64`.

The `--latest` flag is required on Nitro instances, and `t4g` is Nitro. Without
it the command succeeds but returns an empty string, which reads as a broken
instance when nothing is wrong.

This is the one way to see inside an instance you cannot reach over SSH, so it
is the first thing to check when the network looks correct but the login still
fails.

## 9. Feed a value into another command

`--output text` with a scalar query prints the bare value, so it composes:

```sh
IP="$(aws ec2 describe-instances --instance-ids i-0509b70c01d60d18f \
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
ssh -i ~/.ssh/devops-lab-ec2 "ec2-user@${IP}"
```

Terraform outputs give the same values, so `terraform output -raw public_ip` is
shorter while the state file is present. Use the CLI form when you want the fact
from AWS rather than from state, for example after a stop and start, which
changes the address without changing the state file.

## Next

Install Docker with Ansible.
