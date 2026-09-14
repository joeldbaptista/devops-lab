# Manage an EC2 instance

In this project we create and manage an EC2 instance. We use Terraform to
provision the EC2 instance, and then we use Ansible to run a playbook that
installs fundamental utilities and Docker. Once the instance is set up, Docker
runs on it. Then we transfer a dockerised Python application to the instance,
and we run the Docker image there.

## Python app

The Python app is a CLI application that takes one argument, the number of
iterations. In each iteration it prints the timestamp to `stdout`. It waits 10
seconds between iterations, and not after the last one, so `n` iterations take
about `10 × (n - 1)` seconds.

## Sandbox organisation

```sh
README.md
notes/               # numbered notes, one per step performed
app/
  main.py            # the CLI application
  Dockerfile
  deploy.sh          # ships the image to the instance and runs it
  run-remote.sh      # runs the image already on the instance
  remote-common.sh   # defaults and helpers the two scripts share
  Makefile           # build, run, save, deploy, run-remote, clean
terraform/
  *.tf               # the AWS resources
  Makefile           # init, fmt, validate, plan, apply, output, ssh, status, destroy, clean
ansible/
  site.yml           # prepares the instance
  roles/             # common (utilities) and docker
  Makefile           # inventory, ping, check, play, facts, shell, clean
```

## Notes

The `notes/` directory records how each step was performed, so the steps can be
repeated later. Read them in order.

| Note | Subject |
| --- | --- |
| [000](notes/000_how-to-login-to-aws.md) | How to log in to AWS |
| [001](notes/001_how-to-test-credentials-work.md) | How to test the credentials work |
| [002](notes/002_how-to-create-the-ssh-key-pair.md) | How to create the SSH key pair |
| [003](notes/003_how-to-provision-the-ec2-instance-with-terraform.md) | How to provision the EC2 instance with Terraform |
| [004](notes/004_how-to-detect-your-public-ip-address.md) | How to detect your public IP address |
| [005](notes/005_how-to-apply-the-terraform-configuration.md) | How to apply the Terraform configuration |
| [006](notes/006_how-to-destroy-the-instance.md) | How to destroy the instance |
| [007](notes/007_how-to-check-ec2-instances-with-awscli.md) | How to check EC2 instances with the AWS CLI |
| [008](notes/008_how-to-use-the-makefiles.md) | How to use the Makefiles |
| [009](notes/009_how-to-install-docker-with-ansible.md) | How to install Docker with Ansible |
| [010](notes/010_how-to-run-the-ansible-playbook.md) | How to run the Ansible playbook against the instance |
| [011](notes/011_how-to-transfer-the-image-to-the-instance-and-run-it.md) | How to transfer the image to the instance and run it |

## Running it end to end

From nothing to a container running on the instance:

```sh
cd terraform && make apply     # create the instance
cd ../ansible && make play     # install the utilities and Docker
cd ../app && make deploy       # build the image, ship it, run it
```

Terraform provisions, Ansible configures, and `app/deploy.sh` deploys. The first
two steps are idempotent, and the third is not, because it runs the container
every time. A rebuilt instance starts bare, so all three steps are needed again
after `make destroy`.

To run the image again without shipping it again, use `make run-remote` in
`app/`.

## State of the lab

Complete. The Python application, its Dockerfile, the Terraform configuration,
the Ansible playbook with its two roles, the deployment scripts, three
Makefiles, and notes 000 to 011 are all in place. The application image was
transferred to the instance and ran there on 2026-09-14, printing three
timestamps 10 seconds apart. Note 011 records that run and the output it
produced.

The instance is billed while it exists, so run `make destroy` in `terraform/`
when the sandbox is no longer needed. Note 006 covers that step.
