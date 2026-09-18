#!/usr/bin/env bash
#
# List what the lab bucket holds.
#
# The listing is recursive and it always covers the whole prefix, because the
# AWS CLI pages through the results on its own. Three output modes exist, and
# they are mutually exclusive: a human table, bare keys, and raw JSON.

set -euo pipefail

# shellcheck source=s3-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/s3-common.sh"

mode="human"
max=""

usage() {
    cat <<'USAGE'
Usage: list.sh [-b bucket] [-p prefix] [-n max] [-k | -j]

  -b  bucket name; default is `terraform output -raw bucket_name`
  -p  key prefix to list under; default is the whole bucket
  -n  stop after this many objects; default is all of them
  -k  print bare keys only, one per line, for feeding to another command
  -j  print the raw JSON the API returned
  -h  print this message

Environment variables BUCKET, PREFIX, TF_DIR, and AWS set the same values. A
command line option wins over the variable.
USAGE
}

while getopts ':b:p:n:kjh' opt; do
    case "$opt" in
        b) bucket="$OPTARG" ;;
        p) prefix="$OPTARG" ;;
        n) max="$OPTARG" ;;
        k) mode="keys" ;;
        j) mode="json" ;;
        h) usage; exit 0 ;;
        :) echo "list.sh: -$OPTARG needs an argument" >&2; exit 2 ;;
        ?) echo "list.sh: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done

if [ -n "$max" ] && ! [ "$max" -gt 0 ] 2>/dev/null; then
    echo "list.sh: -n takes an integer greater than zero, not '$max'." >&2
    exit 2
fi

normalise_prefix
require_aws
resolve_bucket

# Repeated on every call below. The prefix argument is omitted entirely when no
# prefix was given, because an empty --prefix and no --prefix differ to the CLI.
list() {
    "$aws_bin" s3api list-objects-v2 \
        --bucket "$bucket" \
        ${prefix:+--prefix "$prefix"} \
        ${max:+--max-items "$max"} \
        "$@"
}

# An absent Contents key means the prefix is empty, and length() rejects null,
# so the empty list stands in for it.
count="$(list --query 'length(Contents || `[]`)' --output text)"

if [ "$count" -eq 0 ]; then
    echo "$(s3_path) holds no objects."
    exit 0
fi

case "$mode" in
    json)
        list --output json
        ;;
    keys)
        list --query 'Contents[].Key' --output text | tr '\t' '\n'
        ;;
    human)
        printf 'listing %s\n\n' "$(s3_path)"
        list --query 'Contents[].[Size,LastModified,Key]' --output text | awk '
            function human(bytes,   units, i) {
                split("B KiB MiB GiB TiB", units, " ")
                i = 1
                while (bytes >= 1024 && i < 5) {
                    bytes /= 1024
                    i++
                }
                return sprintf("%.1f %s", bytes, units[i])
            }
            BEGIN { FS = "\t" }
            {
                total += $1
                objects++
                # The timestamp arrives as an ISO instant with an offset, and
                # the offset is always +00:00 here, so it is cut.
                printf "%11s  %s  %s\n", human($1), substr($2, 1, 19), $3
            }
            END { printf "\n%d objects, %s\n", objects, human(total) }
        '
        ;;
esac
