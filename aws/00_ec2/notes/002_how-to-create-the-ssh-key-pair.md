# 002 — How to create the SSH key pair

Ansible reaches the instance over SSH, so the instance needs a key pair before
it is useful. The private key stays on this machine and Terraform imports the
public key into AWS as an EC2 key pair.

Note 001 confirmed that the account held no key pairs, so this step creates the
first one.

## Generate the key

```sh
ssh-keygen -t ed25519 -f ~/.ssh/devops-lab-ec2 -N '' -C 'devops-lab-ec2'
```

That writes two files, and this list is complete:

- `~/.ssh/devops-lab-ec2` — the private key, mode `600`. It never leaves this
  machine and it never enters the repository.
- `~/.ssh/devops-lab-ec2.pub` — the public key, mode `644`. Terraform reads this
  file and imports it.

Three choices behind the command:

- `-t ed25519`, because EC2 accepts ed25519 keys on import and they are shorter
  than RSA keys at equivalent strength.
- `-N ''`, so the key carries no passphrase. That suits a throwaway sandbox and
  it keeps Ansible non-interactive. A key protected by a passphrase would need
  `ssh-agent`.
- The key lives under `~/.ssh`, outside the repository, so no private key can be
  committed by accident.

## Confirm the key

```sh
ssh-keygen -lf ~/.ssh/devops-lab-ec2.pub
```

The key created for this sandbox on 2026-09-14:

```
256 SHA256:2tLQwWevhClK9yBwk22oG6dV7Jav5Ejb64QcqS0Jt3I devops-lab-ec2 (ED25519)
```

## Where the path is configured

The Terraform variable `public_key_path` in `terraform/variables.tf` defaults to
`~/.ssh/devops-lab-ec2.pub`. So a key at a different path needs either a new
default or `-var public_key_path=...` at the command line.

## Next

Provision the instance. See
`003_how-to-provision-the-ec2-instance-with-terraform.md`.
