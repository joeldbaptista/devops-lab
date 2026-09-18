# Manage the Terraform stack for the S3 lab.
#
# Every target here wraps a command recorded in ../notes. The targets that
# change AWS resources, apply and destroy, keep Terraform's interactive
# confirmation. Set AUTO_APPROVE=1 to skip it, which is only sensible in CI.

TF ?= terraform
AWS ?= aws
PROJECT ?= devops-lab-s3

ifeq ($(AUTO_APPROVE),1)
APPROVE := -auto-approve
else
APPROVE :=
endif

.DEFAULT_GOAL := plan
.PHONY: init fmt validate plan apply output uri status describe destroy clean

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

# Creates the bucket and its six configuration resources. Asks for confirmation
# unless AUTO_APPROVE=1.
apply:
	$(TF) apply $(APPROVE)

# Re-print the outputs of the last apply.
output:
	$(TF) output

# Print the s3:// URI on its own, which is the form the AWS CLI takes as a path.
# Resolved at run time, so it fails cleanly when nothing is applied.
uri:
	@$(TF) output -raw s3_uri; echo

# Ask AWS which buckets of this project exist, rather than asking the state
# file. So a bucket deleted outside Terraform shows up as missing here.
status:
	$(AWS) s3api list-buckets \
		--query 'Buckets[?starts_with(Name, `$(PROJECT)`)].{Name:Name,Created:CreationDate}' \
		--output table

# Detail on the bucket named in the state: where it is, whether it versions,
# how it encrypts, and whether it blocks public access.
describe:
	@BUCKET="$$($(TF) output -raw bucket_name)"; \
		echo "bucket:     $$BUCKET"; \
		echo "region:     $$($(AWS) s3api get-bucket-location --bucket "$$BUCKET" --query 'LocationConstraint' --output text)"; \
		echo "versioning: $$($(AWS) s3api get-bucket-versioning --bucket "$$BUCKET" --query 'Status' --output text)"; \
		echo "encryption: $$($(AWS) s3api get-bucket-encryption --bucket "$$BUCKET" \
			--query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text)"; \
		echo "public:     $$($(AWS) s3api get-public-access-block --bucket "$$BUCKET" \
			--query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text) (BlockPublicAcls)"; \
		$(AWS) s3 ls "s3://$$BUCKET" --recursive --summarize | tail -3

# Removes the bucket. force_destroy defaults to true, so a bucket that still
# holds objects goes too. Asks for confirmation unless AUTO_APPROVE=1.
destroy:
	$(TF) destroy $(APPROVE)

# Removes the downloaded providers and any saved plan file. Leaves
# terraform.tfstate alone, because deleting the state would orphan a live
# bucket. Run init again afterwards.
clean:
	rm -rf .terraform
	rm -f *.tfplan
