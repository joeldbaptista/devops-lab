#!/usr/bin/env bash
#
# Copy the application image archive to the EC2 instance, load it into the
# Docker daemon there, and run the container.
#
# The archive is built by `make save`, which writes dist/ec2-lab-app-latest.tar.gz.
# This script does not build it, so run `make deploy` to do both in one step.
#
# Use run-remote.sh instead to run an image that is already on the instance.

set -euo pipefail

# shellcheck source=remote-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/remote-common.sh"

archive=""

usage() {
    cat <<'USAGE'
Usage: deploy.sh [-H host] [-i iterations] [-a archive] [-k ssh_key] [-u user]

  -H  instance address; default is `terraform output -raw public_ip`
  -i  iterations passed to the container; default 3
  -a  image archive to ship; default dist/<image>-<tag>.tar.gz
  -k  SSH private key; default ~/.ssh/devops-lab-ec2
  -u  SSH user; default ec2-user
  -h  print this message

Environment variables IMAGE, TAG, ITERATIONS, SSH_USER, SSH_KEY, TF_DIR, and
REMOTE_DIR set the same values. A command line option wins over the variable.
USAGE
}

while getopts ':H:i:a:k:u:h' opt; do
    case "$opt" in
        H) host="$OPTARG" ;;
        i) iterations="$OPTARG" ;;
        a) archive="$OPTARG" ;;
        k) ssh_key="$OPTARG" ;;
        u) ssh_user="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "deploy.sh: -$OPTARG needs an argument" >&2; exit 2 ;;
        ?) echo "deploy.sh: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done

image_ref="$image:$tag"
archive="${archive:-$app_dir/dist/$image-$tag.tar.gz}"
remote_archive="$remote_dir/$(basename "$archive")"

# The local check is cheaper than reading the Terraform state, so it goes first.
if [ ! -f "$archive" ]; then
    echo "deploy.sh: $archive is missing. Build it with 'make save'." >&2
    exit 1
fi

resolve_host

printf 'shipping %s (%s bytes) to %s@%s\n' \
    "$(basename "$archive")" "$(wc -c < "$archive" | tr -d ' ')" \
    "$ssh_user" "$host"

remote_ssh "mkdir -p '$remote_dir'"
remote_scp "$archive" "$remote_archive"

# The remaining work happens on the instance. The heredoc is quoted, so nothing
# in it expands locally; the three values it needs arrive as positional
# arguments. None of them contains whitespace.
remote_ssh 'bash -s' -- "$remote_archive" "$image_ref" "$iterations" <<'REMOTE'
set -euo pipefail

archive="$1"
image_ref="$2"
iterations="$3"

if ! command -v docker >/dev/null 2>&1; then
    echo "deploy.sh: docker is not installed here." >&2
    echo "deploy.sh: run 'make play' in ansible/ first." >&2
    exit 1
fi

docker load --input "$archive"

# Docker and uname spell the same architecture differently, so translate before
# comparing. A mismatch surfaces as `exec format error`, which does not name
# its own cause, so it is worth catching here.
case "$(uname -m)" in
    aarch64) want=arm64 ;;
    x86_64)  want=amd64 ;;
    *)       want="$(uname -m)" ;;
esac

have="$(docker image inspect --format '{{.Architecture}}' "$image_ref")"
if [ "$have" != "$want" ]; then
    echo "deploy.sh: the image is $have, but this instance needs $want." >&2
    echo "deploy.sh: rebuild it with 'make save PLATFORM=linux/$want'." >&2
    exit 1
fi

echo "loaded $image_ref ($have), running it with $iterations iterations"
docker run --rm "$image_ref" "$iterations"
REMOTE
