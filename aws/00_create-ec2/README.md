# Manage an EC2 instance

In this project we create and manage an EC2 instance. We use Terraform to
provision the EC2 instance, and then we use Ansible to run a playbook that
installs fundamental utilities and Docker. Once the instance is set up, Docker
runs on it. Then we transfer a dockerised Python application to the instance,
and we run the Docker image there.

## Python app

The Python app is a CLI application that takes one argument, the number of
iterations. In each iteration it prints the timestamp to `stdout` and waits 10
seconds.

## Sandbox organisation

```sh
README.md
Makefile
notes/
app/
terraform/
ansible/
```

The `notes/` directory holds numbered notes that record how each step was
performed, so the steps can be repeated later.
