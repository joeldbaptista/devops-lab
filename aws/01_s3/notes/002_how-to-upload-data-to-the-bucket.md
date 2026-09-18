# 002 — How to upload data to the bucket

This note records how `src/upload.sh` sends the contents of `data/` to the
bucket.

## Prerequisites

This list is exhaustive:

- The bucket applied, as note 001 describes.
- A valid login, so `aws sts get-caller-identity` answers.
- Files in `data/`. This sandbox holds three CSV files, about 15 MB together.

## The short version

```sh
cd src
make upload-dry    # what would transfer
make upload        # transfer it
```

## What the script does

`upload.sh` performs five steps in this order, and the list is complete:

1. Checks that the source exists. This is a local check, and it is cheaper than
   reading the Terraform state, so it goes first.
2. Normalises the prefix, so a prefix always names a folder.
3. Checks the AWS CLI is present and the credentials work.
4. Reads the bucket name from `terraform output -raw bucket_name`, unless `-b`
   or `BUCKET` already pinned one.
5. Runs `aws s3 sync` for a directory source, or `aws s3 cp` for a single file.

## Options

```sh
./upload.sh -h                       # the usage message
./upload.sh                          # sync ../data to the bucket root
./upload.sh -p raw                   # sync it under the prefix raw/
./upload.sh -s ../data/one.csv       # copy a single file
./upload.sh -n                       # dry run
./upload.sh -d                       # mirror, so remote extras are deleted
./upload.sh -b some-other-bucket     # ignore the Terraform output
```

Environment variables `BUCKET`, `PREFIX`, `DATA_DIR`, `TF_DIR`, and `AWS` set the
same values, and a command line option wins over the variable.

## Why sync rather than cp for a directory

`aws s3 sync` compares each local file against the object already in the bucket,
and it transfers only what differs. The comparison uses size and modification
time, so a re-run of `make upload` right after the first one transfers nothing
and prints nothing.

`aws s3 cp --recursive` would copy everything every time, which costs requests
and bandwidth for no gain.

Sync does not delete by default, so an object in the bucket that no longer
exists locally stays. Pass `-d`, which adds `--delete`, when the prefix should
mirror the source exactly. Then an object with no local counterpart is removed.

## What a prefix is

S3 has no directories. Every object has one flat key, and a key such as
`raw/2026/report.csv` merely contains slashes. The console draws folders by
splitting keys on the slash, and the API offers `--prefix` to filter by the
start of the key, which is the whole of the resemblance.

In these scripts a prefix always names a folder, so `-p raw` and `-p raw/` mean
the same thing, and a leading slash is dropped. This matters most in
`delete.sh`, where the prefix `re` would otherwise take `reports/` with it.

## Multipart uploads

The AWS CLI splits a file larger than 8 MB into parts and uploads the parts in
parallel. This is automatic, and nothing in the script asks for it. Two of the
three files in `data/` are over that threshold, so they arrive as multipart
uploads.

A multipart upload that fails halfway leaves its parts in the bucket. They are
billed, and `list-objects` does not show them, so the lifecycle rule of note 000
aborts them after seven days.

Two settings govern the behaviour, and both are AWS CLI configuration rather
than script options:

```sh
aws configure set default.s3.multipart_threshold 8MB
aws configure set default.s3.multipart_chunksize 8MB
```

## Content type

`aws s3 sync` guesses the content type from the file extension, so a `.csv` file
arrives as `text/csv`. An unknown extension becomes
`application/octet-stream`. Pass `--content-type` to `aws s3 cp` when that
guess is wrong, which this lab has not needed.

## Encryption

Nothing in the script asks for encryption, and every object is still encrypted,
because the bucket applies SSE-S3 by default. Confirm it on any object:

```sh
aws s3api head-object --bucket "$(terraform -chdir=../terraform output -raw bucket_name)" \
    --key notes.txt --query 'ServerSideEncryption'
```

The answer should be `"AES256"`.

## Verified on 2026-09-19

The option parsing, the usage message, and the three error paths were run: a
missing source, a missing AWS CLI, and expired credentials. Each produced the
message written in the script and the exit status it intends.

The byte counting was run against `data/`, and it reported 15,828,544 bytes
across three files.

No object was uploaded, because the AWS session had expired. So the transfer
itself is unverified.

## Next

See what arrived. See `003_how-to-list-the-bucket-content.md`.
