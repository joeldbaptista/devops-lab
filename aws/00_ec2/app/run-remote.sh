#!/usr/bin/env bash
#
# Run the application image that already sits on the EC2 instance.
#
# This ships nothing. The image must have been loaded there by deploy.sh, so
# `make deploy` is what to run after the image changes, and this is what to run
# to exercise an image that is already in place.

set -euo pipefail

# shellcheck source=remote-common.sh
. "$(dirname "${BASH_SOURCE[0]}")/remote-common.sh"

usage() {
    cat <<'USAGE'
Usage: run-remote.sh [-H host] [-i iterations] [-k ssh_key] [-u user]

  -H  instance address; default is `terraform output -raw public_ip`
  -i  iterations passed to the container; default 3
  -k  SSH private key; default ~/.ssh/devops-lab-ec2
  -u  SSH user; default ec2-user
  -h  print this message

Environment variables IMAGE, TAG, ITERATIONS, SSH_USER, SSH_KEY, and TF_DIR set
the same values. A command line option wins over the variable.
USAGE
}

while getopts ':H:i:k:u:h' opt; do
    case "$opt" in
        H) host="$OPTARG" ;;
        i) iterations="$OPTARG" ;;
        k) ssh_key="$OPTARG" ;;
        u) ssh_user="$OPTARG" ;;
        h) usage; exit 0 ;;
        :) echo "run-remote.sh: -$OPTARG needs an argument" >&2; exit 2 ;;
        ?) echo "run-remote.sh: unknown option -$OPTARG" >&2; usage >&2; exit 2 ;;
    esac
done

image_ref="$image:$tag"
resolve_host

# The announcement of the run itself is made on the instance, after the two
# checks below have passed, so a failure never follows a line claiming the
# container is running.
printf 'using %s@%s\n' "$ssh_user" "$host"

# The remote half runs in a quoted heredoc, so nothing in it expands locally.
# The two values it needs arrive as positional arguments, and neither contains
# whitespace.
remote_ssh 'bash -s' -- "$image_ref" "$iterations" <<'REMOTE'
set -euo pipefail

image_ref="$1"
iterations="$2"

if ! command -v docker >/dev/null 2>&1; then
    echo "run-remote.sh: docker is not installed here." >&2
    echo "run-remote.sh: run 'make play' in ansible/ first." >&2
    exit 1
fi

# Without this check `docker run` would try to pull the image from Docker Hub,
# where it does not exist, and the failure would name a registry rather than the
# real cause.
if ! docker image inspect "$image_ref" >/dev/null 2>&1; then
    echo "run-remote.sh: $image_ref is not on this instance." >&2
    echo "run-remote.sh: run 'make deploy' to put it there." >&2
    exit 1
fi

echo "running $image_ref with $iterations iterations"
docker run --rm "$image_ref" "$iterations"
REMOTE
