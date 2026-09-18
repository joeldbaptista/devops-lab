# 004 — How to delete objects

This note records how `src/delete.sh` removes objects from the bucket. The
script deletes objects, and it never deletes the bucket.

## Prerequisites

This list is exhaustive:

- The bucket applied, as note 001 describes.
- A valid login, so `aws sts get-caller-identity` answers.

## The short version

```sh
cd src
make delete KEY=notes.txt     # one object
make delete PREFIX=raw        # everything under raw/
make empty                    # everything in the bucket
```

Each of these asks for confirmation at the terminal.

## Options

```sh
./delete.sh -k notes.txt                  # one key
./delete.sh -k a.csv -k b.csv             # several keys
./delete.sh -p raw                        # everything under raw/
./delete.sh -a                            # everything in the bucket
./delete.sh -a -n                         # what -a would delete
./delete.sh -p raw -y                     # no confirmation prompt
```

`-k` and `-p` are mutually exclusive, and the script refuses the pair.

## Three guards

The script is the only destructive part of this lab, so it carries three guards.
This list is complete:

1. It refuses to run unarmed. With no `-k`, no `-p`, and no `-a`, it prints the
   usage message and exits 2. So emptying the bucket is never what a mistyped
   command does.
2. It asks before deleting, and the question states the count and the total
   size, so the answer is given against a number rather than blind. `-y` skips
   the prompt, and `-n` never prompts because it deletes nothing.
3. With `-k`, it checks every key with `head-object` before deleting any of
   them. So a typo in the third key does not leave the first two already gone.

A fourth property follows from the second. When stdin is not a terminal the
confirmation cannot be answered, and the script refuses rather than assuming
yes. So a run from `cron` or from a pipeline needs an explicit `-y`.

## Deleting is per object

S3 has no directory to remove, so deleting a prefix means deleting each key
under it. `aws s3 rm --recursive` does the listing and the deletion in one
command, and the script uses it for `-p` and for `-a`.

The deletion itself is not atomic. A failure halfway leaves the earlier objects
gone and the later ones present, and re-running the command finishes the job.

## Versioning changes what delete means

With versioning off, which is the default of this lab, a delete removes the
object and the storage is freed.

With versioning on, a delete adds a delete marker. Then the object disappears
from a normal listing, and its old versions are still stored and still billed.
So `list.sh` reports an empty bucket while the bill stays the same.

Two commands reveal that state:

```sh
aws s3api list-object-versions --bucket "$BUCKET" --query 'Versions[].[Key,VersionId,Size]' --output text
aws s3api list-object-versions --bucket "$BUCKET" --query 'DeleteMarkers[].[Key,VersionId]'  --output text
```

Removing a specific version needs its id:

```sh
aws s3api delete-object --bucket "$BUCKET" --key notes.txt --version-id "$VERSION_ID"
```

`delete.sh` does not handle versions, because the lab runs unversioned. The
lifecycle rule of note 000 expires non-current versions when versioning is
enabled, so the state does clear itself after 30 days.

## Emptying is not destroying

The two are different operations, and they are mutually exclusive answers to
"how do I get rid of this":

- `make empty` in `src/` deletes the objects and keeps the bucket. So the next
  `make upload` refills it, and the bucket name does not change.
- `make destroy` in `terraform/` deletes the bucket and everything in it,
  because `force_destroy` defaults to true. The name is released, and the next
  apply produces a different name.

Note 001 covers the second.

## Troubleshooting

`delete.sh: s3://bucket/key does not exist` on a key you can see in the console
usually means the key has a prefix. The key is the whole path, so
`reports/2026-q1.csv` and `2026-q1.csv` are different keys.

A delete that reports success while `list.sh` still shows the object means
versioning is on, and what you removed was hidden behind a delete marker. See
above.

`AccessDenied` on delete while upload works means the policy grants
`s3:PutObject` and withholds `s3:DeleteObject`.

## Verified on 2026-09-19

The option parsing, the usage message, the mutually exclusive `-k` and `-p`
pair, the refusal to run unarmed, and the credential preflight were all run, and
each behaved as written. The JMESPath query that counts and sums the objects was
evaluated offline against a sample response and against an empty response.

No object was deleted, because the AWS session had expired.

## Next

Learn the Makefile targets. See `005_how-to-use-the-makefiles.md`.
