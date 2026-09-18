# Defaults and helpers shared by upload.sh, list.sh, and delete.sh.
#
# This file is sourced, never executed. It sets the variables the three scripts
# need and defines the helpers, so none of them repeats the bucket lookup or the
# preflight checks.
#
# Every variable below is overridable from the environment, and the sourcing
# script may overwrite any of them from its own command line options.

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bucket="${BUCKET:-}"
prefix="${PREFIX:-}"
tf_dir="${TF_DIR:-$src_dir/../terraform}"
data_dir="${DATA_DIR:-$src_dir/../data}"
aws_bin="${AWS:-aws}"

me="${0##*/}"

# Read the bucket name from the Terraform output, so Terraform stays the single
# source of truth for it. Does nothing when the caller already pinned a name
# with -b or with BUCKET.
resolve_bucket() {
    [ -n "$bucket" ] && return 0

    if ! bucket="$(terraform -chdir="$tf_dir" output -raw bucket_name 2>/dev/null)" || [ -z "$bucket" ]; then
        echo "$me: no bucket_name in the Terraform state." >&2
        echo "$me: run 'make apply' in terraform/, or pass -b <bucket>." >&2
        return 1
    fi
}

# Fail early and with a readable message. Without this the first aws call fails
# instead, and its error names the API call rather than the missing login.
require_aws() {
    if ! command -v "$aws_bin" >/dev/null 2>&1; then
        echo "$me: $aws_bin is not on the PATH." >&2
        return 1
    fi

    if ! "$aws_bin" sts get-caller-identity >/dev/null 2>&1; then
        echo "$me: the AWS credentials are missing or expired." >&2
        echo "$me: run 'aws login' and try again." >&2
        return 1
    fi
}

# A prefix names a folder here, never half a key. So it always ends in a slash,
# and a leading slash is dropped because S3 keys do not start with one. The
# folder rule matters most for delete.sh, where the prefix `re` would otherwise
# take `reports/` with it.
normalise_prefix() {
    prefix="${prefix#/}"
    [ -n "$prefix" ] && prefix="${prefix%/}/"
    return 0
}

# The s3:// path the AWS CLI accepts, with the optional prefix appended.
s3_path() {
    printf 's3://%s/%s' "$bucket" "$prefix"
}

# Ask before doing something irreversible. Returns 0 when the answer is yes.
# Answers no when stdin is not a terminal, so an unattended run never deletes
# anything by accident; pass -y in that case.
confirm() {
    local reply

    if [ ! -t 0 ]; then
        echo "$me: refusing to continue without a terminal. Pass -y to skip the prompt." >&2
        return 1
    fi

    printf '%s [y/N] ' "$1" >&2
    read -r reply
    case "$reply" in
        [yY] | [yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}
