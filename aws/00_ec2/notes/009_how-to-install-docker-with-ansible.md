# 009 — How to install Docker with Ansible

This note records the Ansible installation on the controlling machine, the
contents of `ansible/`, and how to run the playbook against the instance.

Ansible terminology used below: the **control node** is the machine that runs
`ansible-playbook`, which here is the Mac; the **managed node** is the EC2
instance. Ansible installs nothing permanent on the managed node, so only the
control node needs the software.

## Install Ansible on the control node

```sh
brew install ansible
ansible --version
```

Installed on 2026-09-14: `ansible [core 2.21.4]`, from the Homebrew `ansible`
package version 14.4.0, which is 467 MB.

The `ansible` package bundles the collections, so no `ansible-galaxy install`
step is needed. Confirmed present: `amazon.aws` 11.4.0, `ansible.posix` 2.2.2,
and `community.docker` 5.3.0. Installing `ansible-core` alone would give the
engine without those collections.

Nothing is installed on the instance. Ansible connects over SSH and runs Python
modules that Amazon Linux 2023 already satisfies, because the image ships
Python 3.

## Files

```sh
ansible/ansible.cfg              # connection defaults
ansible/site.yml                 # the playbook, which applies two roles
ansible/group_vars/all.yml       # the package list and the docker users
ansible/roles/common/tasks/      # the fundamental utilities
ansible/roles/docker/tasks/      # Docker itself
ansible/Makefile                 # inventory, ping, check, play, facts, shell, clean
ansible/.gitignore               # ignores the generated inventory
```

## The inventory is generated, not written

`inventory.ini` is produced from the Terraform output and it is gitignored:

```sh
make inventory      # writes inventory.ini from terraform output -raw public_ip
```

The file it writes holds two lines:

```ini
[ec2]
<public ip> ansible_user=ec2-user
```

Terraform therefore stays the single source of truth for the address. Every
other target depends on `inventory`, so the file refreshes on each run. That
matters because a destroyed and rebuilt instance carries a different IP, as note
006 explains.

An alternative exists: the `amazon.aws.aws_ec2` dynamic inventory plugin queries
AWS directly and needs no generation step. This lab does not use it, because it
adds a `boto3` dependency and an extra configuration file for one host.

## Connection settings

`ansible.cfg` fixes the connection so no command line flags are needed:

- `remote_user = ec2-user` and `private_key_file = ~/.ssh/devops-lab-ec2`, the
  key from note 002.
- `host_key_checking = False`. This is a deliberate compromise for a sandbox
  whose instances are destroyed and rebuilt. AWS reuses public IP addresses, so
  a rebuilt instance presents a new host key on an address already recorded in
  `~/.ssh/known_hosts`, and strict checking then refuses to connect. Do not copy
  this setting to a production inventory, because it removes the protection
  against a man-in-the-middle.
- `pipelining = True`, which cuts the number of SSH round trips per task.

## What the playbook does

Nine tasks in two roles, and this list is complete:

Role `common`:

1. Upgrade every installed package. Skipped unless `upgrade_all_packages` is
   true, because a full upgrade is slow and can replace the running kernel.
2. Install the utilities `git`, `vim`, `tmux`, `htop`, `jq`, `unzip`, `tar`, and
   `rsync`.
3. Report what was installed.

`curl` is deliberately absent from that list. Amazon Linux 2023 ships
`curl-minimal`, and installing `curl` conflicts with it and fails the task.

Role `docker`:

4. Install the `docker` package, which Amazon Linux 2023 carries in its own
   repositories. So no external Docker repository is added.
5. Enable and start the `docker` service, so it also survives a reboot.
6. Add `ec2-user` to the `docker` group.
7. Reset the connection.
8. Run `docker version` as `ec2-user`, without `sudo`.
9. Report the version lines.

Task 7 is not decoration. A supplementary group applies only to a new login
session, so without the reset the verification in task 8 fails with a permission
error on the Docker socket, although the installation itself succeeded.

## Run it

```sh
cd ansible
make ping     # confirms SSH and Python on the managed node
make check    # dry run, shows the diff without changing the instance
make play     # performs the installation
```

`make` on its own runs `play`, because that is the default goal.

`make check` uses `--check --diff`. One caveat: a check run reports tasks that
depend on an earlier task's effect as failed or skipped, because the earlier
change never happened. So a clean `--check` on a bare instance is not expected.

Two further targets exist: `make facts` prints every fact Ansible gathers, which
is how to find the correct variable name for a new task; `make shell` opens an
interactive SSH session on the same host.

## Verified on 2026-09-14

`ansible-playbook site.yml --syntax-check` passes, and `--list-tasks` resolves
all nine tasks in the two roles. Every target in `ansible/Makefile` expands
correctly under `make -n`.

The playbook has **not** been run against a live instance, because the stack was
destroyed before Ansible was installed. So the task logic is unverified. Running
it needs `make apply` in `terraform/` first, then `make play` here.

## Next

Transfer the dockerised application to the instance and run it.
