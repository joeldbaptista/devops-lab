# 006 — How to check buckets with the AWS CLI

This note records the AWS CLI commands that answer questions about a bucket
directly, without Terraform and without the scripts in `src/`. The Makefile
targets `status` and `describe` wrap some of them.

## Prerequisites

This list is exhaustive:

- AWS CLI v2 on the `PATH`. This sandbox used `aws-cli/2.36.44`.
- A valid login, so `aws sts get-caller-identity` answers.

Most examples below reuse one variable:

```sh
BUCKET="$(terraform -chdir=terraform output -raw bucket_name)"
```

## Two command sets, and when each applies

The CLI offers S3 under two names, and they are not interchangeable:

- `aws s3` is the high level set. It speaks in `s3://` paths, and it has
  `cp`, `ls`, `mv`, `rm`, and `sync`. It handles multipart uploads and
  pagination on its own.
- `aws s3api` is the low level set. Each subcommand maps to one API call, it
  returns the raw response, and `--query` shapes that response.

Use `aws s3` for moving data, and use `aws s3api` for asking precise questions.
The scripts in `src/` use both for exactly that reason.

## Which buckets exist

```sh
aws s3 ls                                    # every bucket in the account
aws s3api list-buckets --output table        # the same, with creation dates
```

Filtered to this lab, which is what `make status` runs:

```sh
aws s3api list-buckets \
    --query 'Buckets[?starts_with(Name, `devops-lab-s3`)].{Name:Name,Created:CreationDate}' \
    --output table
```

The backticks are JMESPath string literals, and the single quotes around the
whole expression stop the shell from treating them as command substitution.

`list-buckets` returns every bucket in the account regardless of region, and it
does not report which region each one is in. So the next command exists.

## Where a bucket is

```sh
aws s3api get-bucket-location --bucket "$BUCKET" --query 'LocationConstraint' --output text
```

`eu-west-1` answers `eu-west-1`. A bucket in `us-east-1` answers `None`, because
that region is the historical default and it is encoded as a null constraint.

## Does a bucket exist, and may I reach it

```sh
aws s3api head-bucket --bucket "$BUCKET" && echo reachable
```

Three outcomes, and this list is complete: an empty response with exit code 0
means yes; `404` means no such bucket; `403` means the bucket exists and belongs
to someone else, or your login lacks permission on it.

## How the bucket is configured

```sh
aws s3api get-bucket-versioning --bucket "$BUCKET"
aws s3api get-bucket-encryption --bucket "$BUCKET"
aws s3api get-public-access-block --bucket "$BUCKET"
aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET"
aws s3api get-bucket-tagging --bucket "$BUCKET"
```

Two of these are worth a warning. `get-bucket-versioning` returns an empty
response when versioning was never enabled, rather than the word `Disabled`. And
`get-bucket-lifecycle-configuration` fails with
`NoSuchLifecycleConfiguration` when no rule exists, rather than returning an
empty list. So a script that reads either one has to allow for that.

## How much is in there

```sh
aws s3 ls "s3://$BUCKET" --recursive --human-readable --summarize | tail -3
```

The last three lines give the object count and the total size. This lists every
key to arrive at the number, so it is slow on a large bucket and it is fine
here.

CloudWatch holds the same numbers without the listing, as the daily metrics
`BucketSizeBytes` and `NumberOfObjects`. They lag by up to 48 hours, so they are
unhelpful right after an upload and they are the right source for a bucket with
millions of keys.

## What a single object is

```sh
aws s3api head-object --bucket "$BUCKET" --key notes.txt
```

The response carries the size, the content type, the ETag, and the encryption.
`head-object` on a missing key fails with `404`, which is what `delete.sh` uses
to check the keys before deleting any of them.

## Who am I

```sh
aws sts get-caller-identity
```

This is the first command to run when anything returns `AccessDenied`, because
the answer names the account and the principal in use. The scripts in `src/`
call it as their preflight check, and they turn its failure into the message
`run 'aws login' and try again`.

## Verified on 2026-09-19

None of these commands was run, because the AWS session had expired. They are
recorded from the AWS CLI documentation and from the `--help` output of the
local CLI, and they are unverified against a live account.

## Next

Nothing follows. Note 000 starts the sequence again.
