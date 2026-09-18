# Manage the Terraform stack for the EC2 lab.
#
# Every target here wraps a command recorded in ../notes. The targets that
# change AWS resources, apply and destroy, keep Terraform's interactive
# confirmation. Set AUTO_APPROVE=1 to skip it, which is only sensible in CI.

TF ?= terraform
AWS ?= aws
PROJECT ?= devops-lab-ec2
SSH_KEY ?= ~/.ssh/devops-lab-ec2
SSH_USER ?= ec2-user

ifeq ($(AUTO_APPROVE),1)
APPROVE := -auto-approve
else
APPROVE :=
endif

.DEFAULT_GOAL := plan
.PHONY: init fmt validate plan apply output ssh status destroy clean

# Download the providers and write the lock file. Needed after a fresh clone or
# a provider version change, and harmless otherwise.
init:
	$(TF) init

# Rewrite the .tf files in canonical style.
fmt:
	$(TF) fmt

# Syntax and type checks. Makes no AWS calls.
validate:
	$(TF) validate

# Read-only. Shows what apply would do.
plan: validate
	$(TF) plan

# Creates the five resources. Asks for confirmation unless AUTO_APPROVE=1.
apply:
	$(TF) apply $(APPROVE)

# Re-print the outputs of the last apply.
output:
	$(TF) output

# Log in to the instance. Reads the address from the Terraform state at run
# time, so it fails cleanly when nothing is applied.
ssh:
	ssh -i $(SSH_KEY) -o StrictHostKeyChecking=accept-new \
		$(SSH_USER)@"$$($(TF) output -raw public_ip)"

# Ask AWS what exists, rather than asking the state file.
status:
	$(AWS) ec2 describe-instances \
		--filters Name=tag:Project,Values=$(PROJECT) \
		          Name=instance-state-name,Values=running,pending,stopped \
		--query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Type:InstanceType,Ip:PublicIpAddress,AZ:Placement.AvailabilityZone}' \
		--output table

# Removes every resource. Asks for confirmation unless AUTO_APPROVE=1.
destroy:
	$(TF) destroy $(APPROVE)

# Removes the downloaded providers and any saved plan file. Leaves
# terraform.tfstate alone, because deleting the state would orphan live AWS
# resources. Run init again afterwards.
clean:
	rm -rf .terraform
	rm -f *.tfplan
