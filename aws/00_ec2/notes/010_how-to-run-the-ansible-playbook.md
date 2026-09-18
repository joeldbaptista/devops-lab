# 010 — How to run the Ansible playbook against the instance

Note 009 covers installing Ansible and the contents of `ansible/`. This note
records the first real run against a live instance, the two faults it exposed,
and the state it produced.

The run used the instance at `3.254.63.107`, provisioned after the first stack
was destroyed. So the address differs from the one in notes 005 and 007.

## The sequence

```sh
cd terraform && make apply     # the instance must exist first
cd ../ansible
make ping                      # writes inventory.ini, then tests the connection
make check                     # dry run
make play                      # the real installation
```

`make ping` succeeded and reported:

```json
3.254.63.107 | SUCCESS => {
    "ansible_facts": {"discovered_interpreter_python": "/usr/bin/python3.9"},
    "changed": false,
    "ping": "pong"
}
```

The interpreter is Python 3.9, which is what Amazon Linux 2023 ships as
`/usr/bin/python3`. Ansible finds it on its own because `ansible.cfg` sets
`interpreter_python = auto_silent`, so no interpreter path needs configuring.

## Fault 1 — a removed callback plugin

The first `make check` failed before contacting the instance:

```
[ERROR]: The 'community.general.yaml' callback plugin has been removed. The
plugin has been superseded by the option `result_format=yaml` in callback
plugin ansible.builtin.default from ansible-core 2.13 onwards. This feature
was removed from collection 'community.general' version 12.0.0.
```

`ansible.cfg` had `stdout_callback = yaml`, which resolves to that removed
plugin. The fix replaces it with the built-in callback plus the option that
superseded it:

```ini
stdout_callback = default
result_format   = yaml
```

## Fault 2 — check mode cannot see what it did not install

With the callback fixed, `make check` reached the instance and then failed:

```
TASK [docker : Enable and start the Docker service]
fatal: FAILED! => {"msg": "Could not find the requested service docker: host"}
```

Check mode does not install the package, so the service unit does not exist and
enabling it fails. Guarding that one task moved the failure to the next
dependent task:

```
TASK [docker : Add the login users to the docker group]
failed: (item=ec2-user) => {"msg": "Group docker does not exist"}
```

The `docker` group is created by the package install, which check mode also
skipped. Guarding tasks one at a time would keep hitting the same class of
failure, so every task that depends on the installed package now sits in one
block:

```yaml
- name: Configure Docker once the package is installed
  when: not ansible_check_mode
  block:
    ...
```

A new dependent task added to the role therefore inherits the guard.

After the change `make check` completes with `failed=0` and `skipped=5`.

One harmless warning remains:

```
[WARNING]: reset_connection task does not support when conditional
```

Ansible ignores `when` on a `meta: reset_connection` task, so that task always
runs. Resetting an SSH connection in check mode changes nothing, so the task
stays inside the block rather than complicating the structure.

## The general lesson about check mode

`--check` predicts changes, and it can only predict them for tasks whose
preconditions already hold. So on a bare host a dry run of a playbook that
installs a package and then configures it cannot be clean by itself. Two ways to
handle that, and they are mutually exclusive:

1. Guard the dependent tasks with `not ansible_check_mode`, which is what this
   playbook does.
2. Accept that `--check` fails on a bare host and run it only against a host
   that is already converged, where it then answers the question "has anything
   drifted".

## State produced on 2026-09-14

Verified on the instance with read-only ad hoc commands after `make play`:

```sh
ansible ec2 -m command -a 'docker --version'
ansible ec2 -b -m command -a 'systemctl is-enabled docker'
ansible ec2 -b -m command -a 'systemctl is-active docker'
ansible ec2 -m command -a 'id ec2-user'
ansible ec2 -m command -a 'rpm -q git vim-enhanced tmux htop jq unzip tar rsync docker'
```

Results:

- `Docker version 25.0.14, build 0bab007`, reported by the client binary.
- The `docker` service is `enabled` and `active`, so it also survives a reboot.
- `id ec2-user` shows `993(docker)` among the groups, so the group membership
  from the playbook took effect.
- Packages installed:

```
git-2.50.1-1.amzn2023.0.1.aarch64
vim-enhanced-9.2.920-1.amzn2023.0.1.aarch64
tmux-3.6a-1.amzn2023.0.1.aarch64
htop-3.2.1-87.amzn2023.0.3.aarch64
jq-1.8.1-60.amzn2023.aarch64
unzip-6.0-68.amzn2023.0.2.aarch64
tar-1.34-1.amzn2023.0.4.aarch64
rsync-3.4.0-1.amzn2023.0.4.aarch64
docker-25.0.16-1.amzn2023.0.4.aarch64
```

Two details in that output are worth noticing. The `vim` package resolves to
`vim-enhanced`, which is the name `rpm -q` needs. And the RPM version,
`25.0.16`, differs from the version string the binary prints, `25.0.14`; both
values are recorded here as observed, and the difference was not investigated.

Every architecture suffix reads `aarch64`, which confirms again that the arm64
AMI and the `t4g.micro` instance type agree.

## Rerunning

The playbook is idempotent, so a second `make play` reports `changed=0`. Running
it after every `make apply` is therefore safe and is the intended workflow,
because a rebuilt instance starts bare.

## Next

Transfer the dockerised application to the instance and run it. That step was
not reached before the instance was destroyed.
