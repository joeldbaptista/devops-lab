# Defaults and helpers shared by deploy.sh and run-remote.sh.
#
# This file is sourced, never executed. It sets the variables both scripts need
# and defines three helpers, so neither script repeats the address lookup or the
# SSH options.
#
# Every variable below is overridable from the environment, and the sourcing
# script may overwrite any of them from its own command line options.

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

image="${IMAGE:-ec2-lab-app}"
tag="${TAG:-latest}"
iterations="${ITERATIONS:-3}"
ssh_user="${SSH_USER:-ec2-user}"
ssh_key="${SSH_KEY:-$HOME/.ssh/devops-lab-ec2}"
tf_dir="${TF_DIR:-$app_dir/../terraform}"
remote_dir="${REMOTE_DIR:-/home/$ssh_user/app}"
host=""

# Read the instance address from the Terraform output, so Terraform stays the
# single source of truth for it. Does nothing when the caller already pinned an
# address with -H.
resolve_host() {
    [ -n "$host" ] && return 0

    if ! host="$(terraform -chdir="$tf_dir" output -raw public_ip 2>/dev/null)" || [ -z "$host" ]; then
        echo "${0##*/}: no public_ip in the Terraform state." >&2
        echo "${0##*/}: run 'make apply' in terraform/, or pass -H <address>." >&2
        return 1
    fi
}

# StrictHostKeyChecking=accept-new matches the Ansible setting, and note 009
# explains why a sandbox whose instances are rebuilt needs it.
remote_ssh() {
    ssh -i "$ssh_key" -o StrictHostKeyChecking=accept-new "$ssh_user@$host" "$@"
}

remote_scp() {
    scp -i "$ssh_key" -o StrictHostKeyChecking=accept-new "$1" "$ssh_user@$host:$2"
}
