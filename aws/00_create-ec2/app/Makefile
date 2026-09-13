# Manage the dockerised Python application.

IMAGE ?= ec2-lab-app
TAG ?= latest
ITERATIONS ?= 3
DOCKER ?= docker

IMAGE_REF := $(IMAGE):$(TAG)

.DEFAULT_GOAL := build
.PHONY: build run clean

build:
	$(DOCKER) build -t $(IMAGE_REF) .

run:
	$(DOCKER) run --rm $(IMAGE_REF) $(ITERATIONS)

clean:
	-$(DOCKER) image rm $(IMAGE_REF)
	rm -rf __pycache__
