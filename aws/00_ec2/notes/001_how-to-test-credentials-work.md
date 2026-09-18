# 001 — How to test the credentials work

This note records the checks that confirm the AWS credentials from
`000_how-to-login-to-aws.md` work, and that the sandbox grants the access this
lab needs. Run the checks in order, because each one assumes the previous one
passed. Every check is read-only, so none of them creates or changes AWS
resources.

## 1. The CLI itself runs

```sh
aws --version
```

Expected: a version line, for example `aws-cli/2.36.44 Python/3.14.7
Darwin/25.6.0 source/arm64`.

A parse error here points at a malformed `~/.aws/credentials`. See the
troubleshooting section of note 000.

## 2. The credential source is the expected one

```sh
aws configure list-profiles
aws configure list
```

Expected in this sandbox: a single profile named `default`, and a table whose
`TYPE` column reads `login` for both `access_key` and `secret_key`:

```
NAME       : VALUE                    : TYPE             : LOCATION
profile    : <not set>                : None             : None
access_key : ****************6AWA     : login            :
secret_key : ****************jTkS     : login            :
region     : eu-west-1                : config-file      : ~/.aws/config
```

`aws configure list` masks all but the last four characters of each key, so the
output is safe to paste into notes or into a chat. The raw values are not.

A `TYPE` of `shared-credentials-file` or `env` means a static key pair is
shadowing the `aws login` credentials. Remove that source first, because the
AWS CLI resolves credentials by precedence and the wrong one may win silently.

## 3. The credentials authenticate

```sh
aws sts get-caller-identity
```

Expected: the account and principal you selected in the browser. This sandbox
returns:

```json
{
    "UserId": "AIDAURPAGN2DDV576EOJ6",
    "Account": "312392183430",
    "Arn": "arn:aws:iam::312392183430:user/joel-admin"
}
```

This call needs no IAM permissions, so it proves authentication only. It does
not prove authorisation.

Failure with `ExpiredToken` or `InvalidClientTokenId` means the cached session
lapsed. Then run `aws login` again.

## 4. The credentials authorise what the lab needs

These four calls stand in for the Terraform and Ansible work that follows. They
cover EC2 networking reads, EC2 key pair reads, and the SSM parameter lookup
that resolves the AMI.

```sh
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock}' --output table

aws ec2 describe-subnets \
  --query 'Subnets[].{Subnet:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}' \
  --output table

aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output text

aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64 \
  --query 'Parameter.Value' --output text
```

Observed in this sandbox on 2026-09-14:

- Default VPC `vpc-03ad94ff35fbeecf7`, CIDR `172.31.0.0/16`.
- Three subnets, one per availability zone, all with public IP mapping on
  launch: `subnet-06f4481ae7a15eb1f` (`eu-west-1a`),
  `subnet-070c2c2b07786dbb3` (`eu-west-1b`),
  `subnet-0e8799b5f6aa570d5` (`eu-west-1c`).
- No key pairs. The empty output is correct, not an error, and it means the lab
  must still create one.
- Amazon Linux 2023 arm64 AMI `ami-0c8fa3e43097681d9`. The AMI id changes
  whenever AWS publishes a new image, so resolve it through this parameter
  rather than hard-coding it.

An `UnauthorizedOperation` or `AccessDenied` response here means the credentials
are valid but the attached IAM policy is too narrow. Then the sandbox needs
permissions for EC2 instances, key pairs, security groups, and the VPC and
subnet lookups.

## Next

Write the Terraform configuration under `terraform/`.
