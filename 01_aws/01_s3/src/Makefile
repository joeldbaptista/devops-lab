# Drive the three bucket scripts.
#
# Every target here wraps a script in this directory, and each script reads the
# bucket name from the Terraform output. So `make apply` in ../terraform must
# have run before any target here works.

AWS ?= aws
TF ?= terraform
TF_DIR ?= ../terraform
DATA_DIR ?= ../data

# Left empty on purpose. BUCKET empty means ask Terraform, and PREFIX empty
# means the whole bucket.
BUCKET ?=
PREFIX ?=
KEY ?=

BUCKET_OPT := $(if $(BUCKET),-b $(BUCKET))
PREFIX_OPT := $(if $(PREFIX),-p $(PREFIX))

.DEFAULT_GOAL := list
.PHONY: check upload upload-dry list keys json delete empty empty-dry

# Confirm the credentials work and the bucket is reachable, before any target
# that moves data. Read-only.
check:
	@$(AWS) sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
	@BUCKET="$(BUCKET)"; \
		[ -n "$$BUCKET" ] || BUCKET="$$($(TF) -chdir=$(TF_DIR) output -raw bucket_name)"; \
		$(AWS) s3api head-bucket --bucket "$$BUCKET" && echo "s3://$$BUCKET is reachable"

# Send ../data to the bucket. A sync, so a second run transfers only what
# changed, and it never deletes anything at the far end.
upload:
	./upload.sh $(BUCKET_OPT) $(PREFIX_OPT) -s $(DATA_DIR)

# What upload would transfer, without transferring it.
upload-dry:
	./upload.sh $(BUCKET_OPT) $(PREFIX_OPT) -s $(DATA_DIR) -n

# The default goal, and read-only, so a bare `make` never changes anything.
list:
	./list.sh $(BUCKET_OPT) $(PREFIX_OPT)

# Bare keys, one per line, for feeding to another command.
keys:
	./list.sh $(BUCKET_OPT) $(PREFIX_OPT) -k

# The raw API response.
json:
	./list.sh $(BUCKET_OPT) $(PREFIX_OPT) -j

# Delete one key, or everything under one prefix. Refuses to run unarmed, so
# emptying the bucket is never what a mistyped target does.
delete:
	@if [ -n "$(KEY)" ]; then \
		./delete.sh $(BUCKET_OPT) -k "$(KEY)"; \
	elif [ -n "$(PREFIX)" ]; then \
		./delete.sh $(BUCKET_OPT) -p "$(PREFIX)"; \
	else \
		echo "make delete needs KEY=<key> or PREFIX=<prefix>." >&2; \
		echo "Use 'make empty' to delete every object in the bucket." >&2; \
		exit 2; \
	fi

# Delete every object in the bucket. The bucket itself stays, so this is not
# `make destroy` in ../terraform. Asks for confirmation.
empty:
	./delete.sh $(BUCKET_OPT) -a

empty-dry:
	./delete.sh $(BUCKET_OPT) -a -n
