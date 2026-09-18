#!/usr/bin/env bash
#
# Delete objects from the lab bucket.
#
# Two modes, mutually exclusive: named keys with -k, or everything under a
# prefix with -p. Emptying the whole bucket needs -a as well, so no run without
# arguments can wipe it. The deletion is confirmed at the terminal unless -y is
# given.
#
# This deletes objects, never the bucket. Use `make destroy` in terraform/ for
# the bucket itself.

set -euo pipefail

# shellcheck source=s3-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/s3-common.sh"

keys=()
delete_all=""
assume_yes=""
dryrun=""

usage() {
    cat <<'USAGE'
Usage: delete.sh [-b bucket] (-k key [-k key ...] | -p prefix | -a) [-y] [-n]

  -b  bucket name; default is `terraform output -raw bucket_name`
  -k  key to delete; repeat the option to name several
  -p  delete every object under this prefix
  -a  delete every object in the bucket; required when no prefix is given
  -y  do not ask for confirmation
  -n  dry run; print what would be deleted and delete nothing
  -h  print this message

Environment variables BUCKET, PREFIX, TF_DIR, and AWS set the same values. A
command line option wins over the variable.
USAGE
}

while getopts ':b:p:k:anyh' opt; do
    case "$opt" in
        b) bucket="$OPTARG" ;;
        p) prefix="$OPTARG" ;;
        k) keys+=("$OPTARG") ;;
        a) delete_all="yes" ;;
        y) assume_yes="yes" ;;
        n) dryrun="--dryrun" ;;
        h) usage; exit 0 ;;
        :) echo "delete.sh: -$OPTARG needs an argument" >&2; exit 2 ;;
        ?) echo "delete.sh: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done

if [ "${#keys[@]}" -gt 0 ] && [ -n "$prefix" ]; then
    echo "delete.sh: -k and -p are mutually exclusive." >&2
    exit 2
fi

if [ "${#keys[@]}" -eq 0 ] && [ -z "$prefix" ] && [ -z "$delete_all" ]; then
    echo "delete.sh: nothing named. Pass -k, or -p, or -a to empty the bucket." >&2
    usage >&2
    exit 2
fi

normalise_prefix
require_aws
resolve_bucket

# Reports the size of what is about to go, so the confirmation carries a number
# the caller can sanity-check rather than a bare yes-or-no.
human_bytes() {
    awk -v bytes="$1" '
        BEGIN {
            split("B KiB MiB GiB TiB", units, " ")
            i = 1
            while (bytes >= 1024 && i < 5) {
                bytes /= 1024
                i++
            }
            printf "%.1f %s\n", bytes, units[i]
        }'
}

if [ "${#keys[@]}" -gt 0 ]; then
    # Check every key before deleting any of them, so a typo in the third key
    # does not leave the first two already gone.
    missing=0
    total=0
    for key in "${keys[@]}"; do
        if size="$("$aws_bin" s3api head-object --bucket "$bucket" --key "$key" \
            --query 'ContentLength' --output text 2>/dev/null)"; then
            total=$((total + size))
        else
            echo "delete.sh: s3://$bucket/$key does not exist." >&2
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -gt 0 ]; then
        echo "delete.sh: $missing of ${#keys[@]} keys are missing, so nothing was deleted." >&2
        exit 1
    fi

    printf 'about to delete %d objects (%s) from s3://%s\n' \
        "${#keys[@]}" "$(human_bytes "$total")" "$bucket"
    printf '  %s\n' "${keys[@]}"

    if [ -z "$assume_yes" ] && [ -z "$dryrun" ]; then
        confirm "delete them?" || { echo "delete.sh: cancelled."; exit 0; }
    fi

    for key in "${keys[@]}"; do
        "$aws_bin" s3 rm "s3://$bucket/$key" ${dryrun:+"$dryrun"}
    done
else
    read -r count total <<<"$("$aws_bin" s3api list-objects-v2 \
        --bucket "$bucket" \
        ${prefix:+--prefix "$prefix"} \
        --query '[length(Contents || `[]`), sum(Contents[].Size || `[0]`)]' \
        --output text)"

    if [ "$count" -eq 0 ]; then
        echo "$(s3_path) holds no objects, so there is nothing to delete."
        exit 0
    fi

    printf 'about to delete %d objects (%s) under %s\n' \
        "$count" "$(human_bytes "${total%.*}")" "$(s3_path)"

    if [ -z "$assume_yes" ] && [ -z "$dryrun" ]; then
        confirm "delete them?" || { echo "delete.sh: cancelled."; exit 0; }
    fi

    "$aws_bin" s3 rm "$(s3_path)" --recursive ${dryrun:+"$dryrun"}
fi

if [ -n "$dryrun" ]; then
    echo "delete.sh: dry run, nothing was deleted."
else
    echo "delete.sh: done. Run list.sh to confirm what remains."
fi
