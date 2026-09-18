# 004 — How to detect your public IP address

The security group in note 003 admits port 22 from one address only, so that
address must be known. This note records how to find it.

The number 004 comes after 003 because the notes are numbered in the order the
steps were performed, although this step is logically a prerequisite of 003.

## Why the address is needed

A security group ingress rule takes a CIDR block, not a host address. So the
address needs a `/32` mask, which denotes exactly one IPv4 address:

```
85.245.154.57  ->  85.245.154.57/32
```

## Three ways to find it

Any one of these is sufficient; they are alternatives, not steps.

```sh
curl -4 -s https://checkip.amazonaws.com                       # AWS's own service
curl -4 -s https://ifconfig.me; echo                           # third-party HTTP service
dig -4 +short myip.opendns.com @resolver1.opendns.com           # DNS, no HTTP involved
```

On 2026-09-14 all three returned `85.245.154.57` for this sandbox.

Prefer the first, for two reasons. It is the service the Terraform
configuration itself queries, so the answers cannot disagree. And it belongs to
AWS, so it does not introduce another third party.

`checkip.amazonaws.com` returns the address followed by a newline. So Terraform
wraps it in `chomp()`, and a shell pipeline needs `tr -d '\n'` before appending
`/32`.

## Force IPv4

Pass `-4` to `curl`, or `-4` to `dig`. Without it, a host that has IPv6
connectivity may report its IPv6 address, and that value is useless for a
`cidr_ipv4` rule. This machine does hold a public IPv6 address, so the flag
matters here.

The instance is not reachable over IPv6 in any case, because the default VPC
carries no IPv6 CIDR block. So the SSH connection uses IPv4 and the `/32` rule
governs it.

## What the address actually identifies

The value is the WAN address of your router, not of your laptop. Three
consequences:

- Every device on the same network shares it, so the rule admits all of them.
- An ISP that uses dynamic addressing or carrier-grade NAT changes it without
  warning, and then SSH stops working until the rule is updated.
- A VPN or a mobile hotspot changes it immediately.

## Use it with Terraform

Terraform detects the address on its own while `allowed_ssh_cidr` stays `null`.
Pin it explicitly when you want a fixed value, for example an office range:

```sh
terraform apply -var 'allowed_ssh_cidr=203.0.113.0/24'
```

Check which CIDR is in force:

```sh
terraform output allowed_ssh_cidr
```

Or read it back from AWS after an apply:

```sh
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=devops-lab-ec2-sg \
  --query 'SecurityGroups[].IpPermissions[].IpRanges[].CidrIp' --output text
```

## When SSH stops working

Compare the two values. A mismatch between your current address and the rule is
the usual cause, and the fix is one more `terraform apply`:

```sh
curl -4 -s https://checkip.amazonaws.com
terraform output allowed_ssh_cidr
```

## Next

Install Docker with Ansible.
