# 001 — How to apply and destroy the bucket

This note records how the bucket is created and how it is removed again. Both
commands run from `terraform/`.

## Prerequisites

This list is exhaustive:

- The configuration of note 000 in place.
- A valid login, so `aws sts get-caller-identity` answers.
- `terraform init` already run once in `terraform/`.

## Create

```sh
cd terraform
make plan     # read-only, shows what apply would do
make apply    # creates the bucket, asks for confirmation
```

`plan` runs `validate` first, so a type error is caught before Terraform
contacts AWS. Apply prints the seven resources it will add and then waits for
the word `yes`. Pass `AUTO_APPROVE=1` to skip the prompt, which is only sensible
in CI.

The outputs follow the apply:

```sh
make output          # every output
make uri             # just the s3:// URI
```

Expect `bucket_name` to read `devops-lab-s3-` followed by eight hexadecimal
characters. That name is what every script in `../src` reads.

## Confirm it exists

Ask AWS rather than the state file:

```sh
make status     # buckets of this project, from list-buckets
make describe   # region, versioning, encryption, public access, size
```

The two differ in what they trust. `status` and `describe` call AWS, and
`output` reads `terraform.tfstate` on disk. So a bucket deleted in the console
still appears in `output` and is absent from `status`.

Note 006 covers the underlying AWS CLI commands.

## Destroy

```sh
cd terraform
make destroy
```

This deletes the bucket. `force_destroy` defaults to `true`, so Terraform empties
the bucket first and the delete then succeeds even when objects remain. Without
that flag S3 answers `BucketNotEmpty`, because S3 refuses to delete a bucket that
still holds anything.

Two consequences follow, and this list is complete:

1. `make destroy` in `terraform/` discards the data as well as the bucket. It is
   not a safe way to tidy up.
2. `make empty` in `../src` deletes the objects and keeps the bucket. That is the
   reversible option, because the next `make upload` refills it.

A destroyed bucket does not come back. The name is released to the global
namespace, and the next `apply` draws a new random suffix, so the new bucket has
a different name. So anything that stored the old name, for example a script
someone pinned with `-b`, has to be updated.

## What this costs

Three charges apply to a bucket like this one, and this list covers the ones
that matter here:

- Storage, billed per GB-month. The 15 MB of `../data` costs a fraction of a
  cent per month in `eu-west-1`.
- Requests, billed per thousand. An upload of three files is three PUT requests.
- Data transfer out to the internet. Nothing here reads the objects from outside
  AWS, so this stays at zero.

So an idle bucket is close to free, which is unlike the EC2 instance of the
previous lab, where the instance is billed per hour while it exists. Destroying
the bucket is therefore about tidiness, and it is not urgent the way
`make destroy` in the EC2 lab was.

The lifecycle rule of note 000 is the backstop. It deletes every object after 30
days, so a forgotten bucket stops accruing storage charges on its own.

## Troubleshooting

`BucketAlreadyExists` on apply means the name is taken somewhere in the world.
This happens only when `bucket_name` was pinned, because the default name
carries a random suffix. Drop the pin, or choose another name.

`AccessDenied` on `PutBucketPolicy` or on any other configuration call means the
login lacks S3 administrative permissions. Check who you are with
`aws sts get-caller-identity`.

`Error: No valid credential sources found` means the session expired. Run
`aws login` again.

## Verified on 2026-09-19

Nothing in this note was run against AWS, because the session had expired. The
Makefile targets were expanded with `make -n`, which prints the commands without
running them, and the commands match what is written above.

## Next

Put the data in the bucket. See `002_how-to-upload-data-to-the-bucket.md`.
