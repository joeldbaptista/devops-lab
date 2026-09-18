# Manage an S3 bucket

In this project we create and manage an S3 bucket. We use Terraform to provision
the bucket, and we then use three Bash scripts to move data in and out of it.
The scripts upload the contents of `data/`, list what the bucket holds, and
delete objects again.

## The data

`data/` holds the payload. This sandbox uses three CSV files, about 15 MB
together. Nothing in the project reads their content, so they can be replaced by
any other files.

Two of the three are larger than 8 MB, which is the AWS CLI threshold for a
multipart upload. So the upload exercises that path without being asked to.

## Sandbox organisation

```sh
README.md
notes/               # numbered notes, one per step performed
data/                # the payload the scripts move
terraform/
  *.tf               # the bucket and its configuration resources
  Makefile           # init, fmt, validate, plan, apply, output, uri, status, describe, destroy, clean
src/
  upload.sh          # sync data/ into the bucket
  list.sh            # report what the bucket holds
  delete.sh          # remove objects, never the bucket
  s3-common.sh       # defaults and helpers the three scripts share
  Makefile           # check, upload, list, keys, json, delete, empty
```

Credentials come from `aws login`, as in the EC2 lab. That step is not repeated
here, and `../00_ec2/notes/000_how-to-login-to-aws.md` records it.

## Notes

The `notes/` directory records how each step was performed, so the steps can be
repeated later. Read them in order.

| Note | Subject |
| --- | --- |
| [000](notes/000_how-to-provision-the-s3-bucket-with-terraform.md) | How to provision the S3 bucket with Terraform |
| [001](notes/001_how-to-apply-and-destroy-the-bucket.md) | How to apply and destroy the bucket |
| [002](notes/002_how-to-upload-data-to-the-bucket.md) | How to upload data to the bucket |
| [003](notes/003_how-to-list-the-bucket-content.md) | How to list the bucket content |
| [004](notes/004_how-to-delete-objects.md) | How to delete objects |
| [005](notes/005_how-to-use-the-makefiles.md) | How to use the Makefiles |
| [006](notes/006_how-to-check-buckets-with-awscli.md) | How to check buckets with the AWS CLI |

## Running it end to end

From nothing to data in the bucket:

```sh
cd terraform && make apply    # create the bucket
cd ../src && make upload      # sync data/ into it
make list                     # see what arrived
```

Terraform provisions, and the scripts move the data. The first two steps are
idempotent: a second `make apply` changes nothing, and a second `make upload`
transfers only what differs, because it is a sync.

Every script reads the bucket name from `terraform output -raw bucket_name`, so
Terraform stays the single source of truth for it. Pass `-b` or set `BUCKET` to
override that.

## Clearing up

Two operations exist, and they are different:

```sh
cd src && make empty          # delete the objects, keep the bucket
cd terraform && make destroy  # delete the bucket and everything in it
```

`make empty` is reversible, because the next `make upload` refills the bucket.
`make destroy` is not, and it also releases the bucket name, so the next apply
produces a bucket with a different random suffix.

A bucket costs storage per GB-month and nothing per hour, so an idle bucket
holding 15 MB is close to free. This differs from the EC2 lab, where the
instance is billed for as long as it exists. The lifecycle rule in the Terraform
configuration deletes every object after 30 days, so a forgotten bucket stops
accruing charges on its own.

## State of the lab

The Terraform configuration, the three scripts with their shared helper file,
the two Makefiles, and notes 000 to 006 are all in place.

Nothing has been run against AWS, because the AWS session had expired while the
project was written. So the following was verified, and the list is complete:
`terraform fmt`, `terraform init`, and `terraform validate` all succeeded; the
variable validation was shown to reject a bad bucket name; every Makefile target
in both files was expanded with `make -n`; every script passed `bash -n`; the
option parsing, usage messages, and error paths of all three scripts were
exercised; and every JMESPath query was evaluated offline against both a
populated and an empty response.

The parts that need AWS are unverified: the apply, the upload, the live listing,
the delete, and the destroy. Run `aws login`, then `cd terraform && make apply`,
to take it from there.
