# 000 — How to provision the S3 bucket with Terraform

This note records the Terraform configuration that creates the bucket for this
lab, and it explains why each resource is there.

Credentials come from `aws login`, exactly as in the EC2 lab. See
`../../00_ec2/notes/000_how-to-login-to-aws.md` for that step, and
`../../00_ec2/notes/001_how-to-test-credentials-work.md` for the check that the
login worked. This note assumes a working login.

## Prerequisites

This list is exhaustive:

- Terraform 1.6 or later. This sandbox used Terraform v1.16.0.
- AWS CLI v2 on the `PATH`. This sandbox used `aws-cli/2.36.44`.
- A valid login, so `aws sts get-caller-identity` answers.

## The files

```sh
terraform/versions.tf    # required versions, the provider, the default tags
terraform/variables.tf   # every input, each with a default
terraform/main.tf        # the bucket and its configuration resources
terraform/outputs.tf     # what the scripts in ../src read
terraform/Makefile       # the commands of note 005
```

## The resources

Terraform creates seven resources, and this list is complete:

| Resource | Purpose |
| --- | --- |
| `random_id.suffix` | Four random bytes appended to the bucket name |
| `aws_s3_bucket.lab` | The bucket itself |
| `aws_s3_bucket_public_access_block.lab` | Refuses public access four ways |
| `aws_s3_bucket_ownership_controls.lab` | Switches ACLs off |
| `aws_s3_bucket_server_side_encryption_configuration.lab` | SSE-S3 on every object |
| `aws_s3_bucket_versioning.lab` | Versioning, off by default |
| `aws_s3_bucket_lifecycle_configuration.lab` | Expiry rules that cap the spend |

A bucket is one resource plus a set of separate configuration resources, which
differs from an EC2 instance, where most settings are arguments of the instance
itself. The separate resources each map to their own S3 API call, for example
`PutBucketVersioning`, so Terraform's split follows the API.

### Why the random suffix

Bucket names live in one global namespace shared by every AWS account. So
`devops-lab-s3` is very likely taken already, and creating it would fail with
`BucketAlreadyExists`. The four random bytes produce a name such as
`devops-lab-s3-3f9a1c7e`, which is unique in practice.

Set `bucket_name` to pin the name instead. Then the suffix resource is not
created at all, because its `count` is zero.

### Why the public access block

Four settings, and the block turns on all four: `block_public_acls`,
`ignore_public_acls`, `block_public_policy`, and `restrict_public_buckets`. The
first and third refuse a new public grant, and the second and fourth ignore any
public grant that already exists. A bucket left readable by the world is the
classic S3 accident, so a sandbox bucket blocks that from the start.

### Why ACLs are off

`object_ownership = "BucketOwnerEnforced"` disables ACLs entirely, so access is
decided by IAM policy and by the bucket policy alone. This matches what the
console does for a new bucket today, and it removes a second permission system
that would otherwise have to agree with the first.

### Why SSE-S3 rather than SSE-KMS

`AES256` means SSE-S3, where AWS holds the key. It costs nothing, and it applies
to every object whether or not the uploader asks for it. The alternative is
SSE-KMS with a customer managed key, which is billed monthly per key plus a
charge per request, and this lab does not need it.

`bucket_key_enabled = true` is harmless under SSE-S3 and it cuts KMS request
charges if the bucket is ever switched to SSE-KMS.

### Why versioning is off by default

A versioned bucket answers a plain delete with a delete marker. The object is
then invisible to a normal listing, but it is still stored, and it is still
billed. So the default here is off, which keeps `delete.sh` honest. Turn it on
with `-var versioning_enabled=true` when the lab is about versioning itself.

One asymmetry is worth knowing. A bucket that has never been versioned accepts
the status `Disabled`. A bucket that has been versioned once may only be
`Suspended` afterwards, so the variable cannot fully undo itself.

### Why the lifecycle rules exist

Two rules, and this list is complete:

1. `abort-incomplete-multipart-uploads` discards the parts of a multipart upload
   that never completed, seven days after it started. Those parts are billed,
   and no `list-objects` call reveals them, so they are easy to forget.
2. `expire-objects` deletes every object after `expire_objects_after_days` days,
   which is 30 by default. Set the variable to zero to drop this rule.

Both rules carry an empty `filter {}` block, which selects every object. The
block is required even when it selects everything.

## The variables

Six variables, every one with a default, and this list is complete:

| Variable | Default | Meaning |
| --- | --- | --- |
| `region` | `eu-west-1` | Region that holds the bucket |
| `project` | `devops-lab-s3` | Name prefix and `Project` tag |
| `bucket_name` | `null` | Full name; null means project plus random suffix |
| `force_destroy` | `true` | Let `destroy` remove a bucket that still holds objects |
| `versioning_enabled` | `false` | Keep old versions of an object |
| `expire_objects_after_days` | `30` | Lifecycle expiry; zero disables the rule |

Three of them are validated, so a bad value fails before Terraform calls AWS:
`project` and `bucket_name` must match the S3 naming rules, and
`expire_objects_after_days` must not be negative.

## The outputs

Six outputs, and this list is complete: `bucket_name`, `bucket_arn`,
`bucket_region`, `bucket_domain_name`, `s3_uri`, and `versioning_status`.

`bucket_name` matters most, because every script in `../src` reads it with
`terraform output -raw bucket_name`. So Terraform stays the single source of
truth for the bucket name, exactly as it was for the instance address in the EC2
lab.

## Verified on 2026-09-19

`terraform fmt`, `terraform init`, and `terraform validate` were all run, and
validate reported the configuration valid. The providers resolved to
`hashicorp/aws v6.65.0` and `hashicorp/random v3.9.1`.

The validation rule on `bucket_name` was exercised with
`terraform plan -var 'bucket_name=NOT_VALID'`, and it rejected the value before
the provider was reached.

No AWS resource was created, because the AWS session had expired when this note
was written. So the plan and the apply are still unverified against a live
account.

## Next

Apply the configuration. See `001_how-to-apply-and-destroy-the-bucket.md`.
