# Drive the Ansible playbook against the EC2 instance.
#
# The inventory is generated from the Terraform state, so Terraform stays the
# single source of truth for the instance address.

ANSIBLE ?= ansible
PLAYBOOK ?= ansible-playbook
TF ?= terraform
TF_DIR ?= ../terraform
INVENTORY ?= inventory.ini
SSH_USER ?= ec2-user

.DEFAULT_GOAL := play
.PHONY: inventory ping check play facts shell clean

# Write inventory.ini from the Terraform output. Re-run it after every apply,
# because a rebuilt instance carries a new public IP.
inventory:
	@IP="$$($(TF) -chdir=$(TF_DIR) output -raw public_ip)"; \
		printf '[ec2]\n%s ansible_user=%s\n' "$$IP" "$(SSH_USER)" > $(INVENTORY); \
		echo "wrote $(INVENTORY) for $$IP"

# Confirm Ansible reaches the host over SSH.
ping: inventory
	$(ANSIBLE) ec2 -m ping

# Show what the playbook would change, without changing anything.
check: inventory
	$(PLAYBOOK) site.yml --check --diff

# Install the utilities and Docker.
play: inventory
	$(PLAYBOOK) site.yml

# Print every fact Ansible gathers about the host. Useful when a task needs a
# variable and the right name is unclear.
facts: inventory
	$(ANSIBLE) ec2 -m setup

# Open an interactive shell on the instance, using the generated inventory.
shell: inventory
	ssh -i ~/.ssh/devops-lab-ec2 -o StrictHostKeyChecking=accept-new \
		$(SSH_USER)@"$$($(TF) -chdir=$(TF_DIR) output -raw public_ip)"

clean:
	rm -f $(INVENTORY)
