# 003 — How to list the bucket content

This note records how `src/list.sh` reports what the bucket holds.

## Prerequisites

This list is exhaustive:

- The bucket applied, as note 001 describes.
- A valid login, so `aws sts get-caller-identity` answers.

## The short version

```sh
cd src
make list      # the default goal, so a bare `make` does this
```

## Options

```sh
./list.sh                 # every object, as a table with sizes
./list.sh -p raw          # only the keys under raw/
./list.sh -n 10           # stop after ten objects
./list.sh -k              # bare keys, one per line
./list.sh -j              # the raw JSON the API returned
./list.sh -b other-bucket # ignore the Terraform output
```

The three output modes are mutually exclusive: the human table, which is the
default; bare keys with `-k`; and raw JSON with `-j`.

The human table looks like this:

```
listing s3://devops-lab-s3-3f9a1c7e/

    9.0 MiB  2026-09-19T00:20:01  annual-enterprise-survey-2025-financial-year-provisional.csv
    2.2 MiB  2026-09-19T00:20:02  business-operations-survey-2022-price-and-wage-setting.csv
    3.9 MiB  2026-09-19T00:20:03  machine-readable-business-employment-data-june-2026-quarter.csv

3 objects, 15.1 MiB
```

`-k` exists so the output can feed another command:

```sh
./list.sh -k -p raw | xargs -I{} ./delete.sh -k {} -y
```

## Why list-objects-v2 rather than `aws s3 ls`

`aws s3 ls` is the friendlier command, and the script does not use it, for three
reasons. This list is complete:

1. `aws s3 ls` exits non-zero when a prefix matches nothing, which under
   `set -e` aborts the script instead of reporting an empty prefix.
2. It has no equivalent of `--max-items`, so `-n` could not be honoured.
3. Its output format is fixed, so the three modes would need three different
   commands rather than three queries over one response.

`aws s3api list-objects-v2` returns the raw API response, and `--query` then
shapes it. The formatting is done by a short `awk` program, which sums the sizes
and prints the total.

## Pagination

The API returns at most 1000 keys per call, and it returns a continuation token
when more remain. The AWS CLI follows that token on its own and merges the pages
before `--query` runs. So the script never handles pagination itself, and the
listing always covers the whole prefix.

`--max-items` stops that paging early, which is what `-n` uses.

## The empty case

An empty prefix produces a response with no `Contents` key at all, and not an
empty list. So `length(Contents)` would fail on null, and the script asks for
`length(Contents || `[]`)` instead, where the empty list stands in for the
missing key. A count of zero then prints one line and exits successfully:

```
s3://devops-lab-s3-3f9a1c7e/ holds no objects.
```

## What a listing does not show

Three things, and this list is complete:

- Parts of an incomplete multipart upload. Use
  `aws s3api list-multipart-uploads --bucket "$BUCKET"`.
- Old versions and delete markers, when versioning is on. Use
  `aws s3api list-object-versions --bucket "$BUCKET"`.
- Anything about the bucket itself, for example its encryption or its region.
  Use `make describe` in `terraform/`, which note 006 explains.

## Verified on 2026-09-19

The option parsing, the usage message, and the two preflight failures were run.
Every JMESPath query in the script was evaluated offline against a sample
response and against an empty response, and all four behaved as the script
assumes. The `awk` formatter was run on a sample of three rows, and it produced
the table shown above.

No live listing was made, because the AWS session had expired.

## Next

Remove objects again. See `004_how-to-delete-objects.md`.
