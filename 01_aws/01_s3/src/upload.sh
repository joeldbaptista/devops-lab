#!/usr/bin/env bash
#
# Upload the contents of data/ to the lab bucket.
#
# A directory source is synchronised, so a second run transfers only what
# changed. A single file source is copied. The bucket name comes from the
# Terraform output, so `make apply` in terraform/ must have run first.

set -euo pipefail

# shellcheck source=s3-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/s3-common.sh"

source_path="$data_dir"
dryrun=""
mirror=""

usage() {
    cat <<'USAGE'
Usage: upload.sh [-b bucket] [-p prefix] [-s source] [-d] [-n]

  -b  bucket name; default is `terraform output -raw bucket_name`
  -p  key prefix to upload under; default is the bucket root
  -s  file or directory to upload; default is ../data
  -d  also delete objects under the prefix that the source no longer has,
      which makes the prefix an exact mirror of the source
  -n  dry run; print what would transfer and transfer nothing
  -h  print this message

Environment variables BUCKET, PREFIX, DATA_DIR, TF_DIR, and AWS set the same
values. A command line option wins over the variable.
USAGE
}

while getopts ':b:p:s:dnh' opt; do
    case "$opt" in
        b) bucket="$OPTARG" ;;
        p) prefix="$OPTARG" ;;
        s) source_path="$OPTARG" ;;
        d) mirror="--delete" ;;
        n) dryrun="--dryrun" ;;
        h) usage; exit 0 ;;
        :) echo "upload.sh: -$OPTARG needs an argument" >&2; exit 2 ;;
        ?) echo "upload.sh: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done

# The local check is cheaper than reading the Terraform state, so it goes first.
if [ ! -e "$source_path" ]; then
    echo "upload.sh: $source_path does not exist." >&2
    exit 1
fi

if [ -n "$mirror" ] && [ ! -d "$source_path" ]; then
    echo "upload.sh: -d applies to a directory source, and $source_path is a file." >&2
    exit 2
fi

normalise_prefix
require_aws
resolve_bucket

destination="$(s3_path)"

if [ -d "$source_path" ]; then
    count="$(find "$source_path" -type f | wc -l | tr -d ' ')"
    # wc -c on a file argument reads its size from the inode, so this costs
    # nothing even when data/ holds megabytes. The "total" lines wc prints for
    # a multi-file batch are excluded, or the sum would double.
    bytes="$(find "$source_path" -type f -exec wc -c {} + | awk '$2 != "total" { s += $1 } END { print s + 0 }')"
    printf 'syncing %s (%s files, %s bytes) to %s\n' \
        "$source_path" "$count" "$bytes" "$destination"

    # --delete is withheld unless -d was given, so an upload never removes
    # anything the caller did not ask it to remove.
    "$aws_bin" s3 sync "$source_path" "$destination" ${mirror:+"$mirror"} ${dryrun:+"$dryrun"}
else
    printf 'copying %s (%s bytes) to %s%s\n' \
        "$source_path" "$(wc -c < "$source_path" | tr -d ' ')" \
        "$destination" "$(basename "$source_path")"

    "$aws_bin" s3 cp "$source_path" "$destination$(basename "$source_path")" ${dryrun:+"$dryrun"}
fi

if [ -n "$dryrun" ]; then
    echo "upload.sh: dry run, nothing was transferred."
else
    echo "upload.sh: done. Run list.sh to see what the bucket now holds."
fi
