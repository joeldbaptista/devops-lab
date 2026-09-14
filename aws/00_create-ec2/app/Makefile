# Manage the dockerised Python application.
#
# build and run act on the control machine. save writes the archive, deploy
# ships that archive to the EC2 instance and runs it there, and run-remote runs
# the image already on the instance without shipping anything.

IMAGE ?= ec2-lab-app
TAG ?= latest
ITERATIONS ?= 3
DOCKER ?= docker

# The instance is a t4g.micro, which is arm64. Pinning the platform keeps the
# image loadable there whatever architecture the build machine uses.
PLATFORM ?= linux/arm64

IMAGE_REF := $(IMAGE):$(TAG)
DIST := dist
ARCHIVE := $(DIST)/$(IMAGE)-$(TAG).tar.gz

.DEFAULT_GOAL := build
.PHONY: build run save deploy run-remote clean

# --provenance=false drops the attestation manifest that buildx attaches by
# default. That manifest carries the build time, so leaving it in makes every
# rebuild produce a different archive even when the image itself is unchanged.
build:
	$(DOCKER) build --platform $(PLATFORM) --provenance=false -t $(IMAGE_REF) .

run:
	$(DOCKER) run --rm $(IMAGE_REF) $(ITERATIONS)

# Write the image to a gzipped tar archive. This is the artefact that travels to
# the instance, so no registry is involved. gzip -n omits the timestamp, so an
# unchanged image always produces the same archive, and the copy on the instance
# can then be compared against this one by checksum.
save: build
	mkdir -p $(DIST)
	$(DOCKER) save $(IMAGE_REF) | gzip -n > $(ARCHIVE)
	@ls -lh $(ARCHIVE)

# Copy the archive to the instance, load it into the Docker daemon there, and
# run the container. deploy.sh reads the address from the Terraform output, so
# the instance must exist, and it must already carry Docker from `make play`.
deploy: save
	IMAGE=$(IMAGE) TAG=$(TAG) ./deploy.sh -i $(ITERATIONS)

# Run the image that deploy already put on the instance. So this ships nothing
# and it does not rebuild, which makes it the quick way to exercise the image
# again, or to run it with a different iteration count.
run-remote:
	IMAGE=$(IMAGE) TAG=$(TAG) ./run-remote.sh -i $(ITERATIONS)

clean:
	-$(DOCKER) image rm $(IMAGE_REF)
	rm -rf $(DIST) __pycache__
