# 005 — How to use the Makefiles

Two Makefiles exist, one per component, and each one wraps the commands recorded
in the earlier notes. Neither knows about the other, so each is run from its own
directory.

```sh
terraform/Makefile   # manages the bucket
src/Makefile         # drives the three scripts
```

A Makefile recipe must be indented with a tab character, never with spaces. So
an editor that converts tabs to spaces breaks the file, and `make` then reports
`missing separator`.

## terraform/Makefile

```sh
cd terraform
make            # same as make plan, because plan is the default goal
make init       # download providers, write the lock file
make fmt        # rewrite the .tf files in canonical style
make validate   # syntax and type checks, no AWS calls
make plan       # runs validate first, then shows what apply would do
make apply      # create the bucket, with Terraform's confirmation prompt
make output     # re-print the outputs of the last apply
make uri        # print just the s3:// URI
make status     # ask AWS which buckets of this project exist
make describe   # region, versioning, encryption, public access, size
make destroy    # remove the bucket, with Terraform's confirmation prompt
make clean      # remove .terraform/ and any saved plan file
```

The default goal is `plan`, so a bare `make` never changes anything.

Three variables are overridable at the command line: `TF` (default `terraform`),
`AWS` (default `aws`), and `PROJECT` (default `devops-lab-s3`).

`apply` and `destroy` keep the interactive confirmation. Pass `AUTO_APPROVE=1` to
add `-auto-approve`:

```sh
make apply AUTO_APPROVE=1
```

Four design points worth remembering:

- `plan` depends on `validate`, so a type error is caught before Terraform
  contacts AWS.
- `uri` and `describe` resolve the bucket name at run time, inside the recipe,
  rather than when `make` parses the file. So they fail cleanly when nothing is
  applied, instead of breaking every other target in the file.
- `status` asks AWS, while `output` asks the local state file. The two disagree
  when a bucket is deleted outside Terraform.
- `clean` deliberately leaves `terraform.tfstate` in place. Deleting the state
  would orphan a live bucket. So `clean` removes only `.terraform/`, which holds
  the downloaded providers, and any `*.tfplan` file. Run `make init` afterwards.

This mirrors the EC2 lab, where one target differs. There `make ssh` opened a
shell on the instance, and here `make uri` prints the path instead, because a
bucket is not something to log in to.

## src/Makefile

```sh
cd src
make            # same as make list
make check      # who am I, and is the bucket reachable
make upload     # sync ../data into the bucket
make upload-dry # what upload would transfer
make list       # every object, as a table with sizes
make keys       # bare keys, one per line
make json       # the raw API response
make delete     # needs KEY= or PREFIX=
make empty      # delete every object, with a confirmation prompt
make empty-dry  # what empty would delete
```

The default goal is `list`, which is read-only, so a bare `make` never changes
anything here either.

Six variables are overridable: `AWS` (default `aws`), `TF` (default
`terraform`), `TF_DIR` (default `../terraform`), `DATA_DIR` (default `../data`),
`BUCKET` (empty), and `PREFIX` (empty). A seventh, `KEY`, exists only for
`delete`.

`BUCKET` and `PREFIX` are empty on purpose. An empty `BUCKET` means ask
Terraform for the name, and an empty `PREFIX` means the whole bucket.

```sh
make list PREFIX=raw
make upload PREFIX=raw DATA_DIR=../data
make delete KEY=notes.txt
make delete PREFIX=raw
make list BUCKET=some-other-bucket
```

`delete` refuses to run without `KEY` or `PREFIX`, and it names `make empty` as
the way to clear everything. So the destructive case always has to be asked for
by name.

## The two destructive targets

They are different, and confusing them costs the bucket:

| Target | Directory | Effect |
| --- | --- | --- |
| `make empty` | `src/` | Objects go, the bucket stays |
| `make destroy` | `terraform/` | The bucket goes, and everything in it |

Note 004 covers the difference in full.

## Verified on 2026-09-19

Every target in both files was expanded with `make -n`, which prints the
commands without running them. The read-only Terraform targets `fmt`,
`validate`, and `init` were also run for real, and `plan` was run far enough to
prove the variable validation fires.

The targets that call AWS are unverified beyond their expansion, because the AWS
session had expired.

## Next

Inspect buckets from the command line. See
`006_how-to-check-buckets-with-awscli.md`.
