SHELL := /bin/sh

STACK_DIR := stacks/do
LOCAL_TF_DIR := $(abspath ../open24-config-stay-local/tf/do)
BACKEND_CONFIG := $(LOCAL_TF_DIR)/backend.hcl
TFVARS := $(LOCAL_TF_DIR)/terraform.tfvars
TF := terraform -chdir=$(STACK_DIR)

.PHONY: help check init fmt validate plan apply destroy output show

help:
	@echo "DigitalOcean Terraform targets"
	@echo "  make -f Makefile.do init"
	@echo "  make -f Makefile.do plan"
	@echo "  make -f Makefile.do apply"
	@echo "  make -f Makefile.do destroy"

check:
	@test -d "$(STACK_DIR)" || (echo "Missing stack dir: $(STACK_DIR)" && exit 1)
	@test -f "$(BACKEND_CONFIG)" || (echo "Missing backend config: $(BACKEND_CONFIG)" && exit 1)
	@test -f "$(TFVARS)" || (echo "Missing tfvars: $(TFVARS)" && exit 1)

init: check
	$(TF) init -backend-config=$(BACKEND_CONFIG)

fmt:
	terraform fmt -recursive stacks/do

validate: check
	$(TF) validate

plan: check
	$(TF) plan -var-file=$(TFVARS)

apply: check
	$(TF) apply -var-file=$(TFVARS)

destroy: check
	$(TF) destroy -var-file=$(TFVARS)

output: check
	$(TF) output

show: check
	$(TF) show
