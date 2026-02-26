.EXPORT_ALL_VARIABLES:
.ONESHELL:
.SILENT:

MAKEFLAGS += --no-builtin-rules --no-builtin-variables

default: help

###############################################################################
# Variables
###############################################################################

google_project ?= mailpilot-pilot-dev1
google_region ?= us-east5
google_zone ?= $(google_region)-b

###############################################################################
# Settings
###############################################################################

git_root := $(shell git rev-parse --show-toplevel)
root_dir := $(git_root)
secrets_dir := $(root_dir)/secrets

settings: ## Display settings
	$(call header,Settings)
	$(call var,google_project,$(google_project))
	$(call var,google_region,$(google_region))
	$(call var,google_zone,$(google_zone))

clean: terraform-clean

###############################################################################
# Release Targets
###############################################################################

mailpilot-pilot-dev1:
	set -e
	$(call header,Deploy $(yellow)$(@)$(reset))
	$(MAKE) terraform-apply google_project=$(@)
	$(MAKE) pilot-configure google_project=$(@)
	$(MAKE) pilot-deploy google_project=$(@)

###############################################################################
# Ansible
###############################################################################

ansible_dir := $(root_dir)/ansible
ansible_user := ubuntu
ansible_inventory := $(ansible_dir)/inventory
ansible_ssh_key := $(secrets_dir)/ssh.key
ansible_signing_key := $(secrets_dir)/github-signing.key
ansible_args := --inventory $(ansible_inventory) --user $(ansible_user) --private-key $(ansible_ssh_key) --extra-vars ansible_python_interpreter='/usr/bin/python3.12'

SSH_COMMON_ARGS := -o StrictHostKeyChecking=no
ANSIBLE_HOST_KEY_CHECKING := False

$(ansible_ssh_key):
	gpg $@.gpg && chmod 600 $@

$(ansible_signing_key):
	gpg $@.gpg && chmod 600 $@

ansible-inventory:
	$(call header,Ansible Inventory)
	-rm -rf $(ansible_inventory)/*
	jq -r '.ansible_hosts.value[] | "\(.name) \(.dns) \(.ip)"' $(terraform_dir)/output.json | while read -r name dns ip; do
	    echo "$(green)Creating inventory file for $(yellow)$${dns} in zone $(google_zone)"
	    echo $${dns} > $(ansible_inventory)/$$name
	done

ansible-ready: ansible-inventory $(ansible_ssh_key) $(ansible_signing_key)

ansible-clean:
	$(MAKE) -C secrets clean
	-jq -r '.ansible_hosts.value[].dns' $(terraform_dir)/output.json 2>/dev/null | while read -r host; do \
		ssh-keygen -f ~/.ssh/known_hosts -R "$$host" > /dev/null 2>&1; \
	done

###############################################################################
# Pilot App Deployment
###############################################################################

ANTHROPIC_API_KEY = $(shell gpg -d $(secrets_dir)/ANTHROPIC_API_KEY.gpg 2>/dev/null)
GITHUB_TOKEN = $(shell gpg -d $(secrets_dir)/GITHUB_TOKEN.gpg 2>/dev/null)

pilot-configure: ansible-ready
	$(call header,Ansible VM Ping)
	for i in 1 2 3 4 5; do
		echo "Connectivity Test $$i of 5";
		ansible all --module-name ping $(ansible_args) && break ||
		if [ $$i -eq 5 ]; then
			echo "$(red)Failed after 5 attempts";
			exit 1;
		else
			echo "$(yellow)Retrying in 6 seconds...";
			sleep 6;
		fi;
	done
	$(call header,Ansible VM Configuration)
	ansible-playbook $(ansible_args) \
	ansible/playbook-vm-config.yaml

pilot-deploy: ansible-ready ## Deploy Pilot app (pilot_version=X.Y.Z)
	$(eval pilot_version ?= $(shell gh release view --repo kborovik/pilot --json tagName -q '.tagName' 2>/dev/null | sed 's/^v//'))
	@if [ -z "$(pilot_version)" ]; then \
		echo "$(red)Error: pilot_version required. Usage: make pilot-deploy pilot_version=1.2.3$(reset)"; \
		exit 1; \
	fi
	$(call header,Deploy Pilot $(yellow)v$(pilot_version)$(reset) to $(yellow)$(google_project)$(reset))
	ansible-playbook $(ansible_args) \
		--extra-vars 'pilot_version=$(pilot_version) pilot_anthropic_api_key=$(ANTHROPIC_API_KEY) pilot_github_token=$(GITHUB_TOKEN)' \
		ansible/playbook-pilot-deploy.yaml

pilot-rollback: ansible-ready ## Rollback Pilot to previous release
	$(call header,Rollback Pilot on $(yellow)$(google_project)$(reset))
	ansible $(ansible_args) all -m shell -a \
		"prev=$$(ls -1dt /home/ubuntu/pilot/releases/*/ | sed -n 2p) && ln -sfn $$prev /home/ubuntu/pilot/current && systemctl restart pilot && readlink /home/ubuntu/pilot/current"

pilot-status: ansible-ready ## Check Pilot service status
	$(call header,Pilot Status on $(yellow)$(google_project)$(reset))
	ansible $(ansible_args) all -m shell -a \
		"systemctl status pilot --no-pager; echo '---'; readlink /home/ubuntu/pilot/current"

###############################################################################
# Terraform
###############################################################################

.PHONY: terraform

terraform_dir := $(root_dir)/terraform
terraform_tfvars := $(terraform_dir)/$(google_project).tfvars
terraform_output := $(terraform_dir)/$(google_project).json
terraform_bucket := terraform-$(google_project)

CLOUDFLARE_API_TOKEN = $(shell gpg -d $(secrets_dir)/CLOUDFLARE_API_TOKEN.gpg 2>/dev/null)

terraform: terraform-plan prompt terraform-apply ## Run Terraform Plan + Apply

terraform-config:
	$(call header,Configure Terraform)
	ln -fs $(terraform_tfvars) $(terraform_dir)/terraform.tfvars

terraform-fmt: terraform-config
	$(call header,Check Terraform Code Format)
	terraform -chdir=$(terraform_dir) fmt -check -recursive

ifeq ($(wildcard $(terraform_tfvars)),)
	$(warning ==> $(terraform_tfvars) not found <==)
endif

terraform-init: terraform-fmt
	$(call header,Initialize Terraform)
	terraform -chdir=$(terraform_dir) init -upgrade -reconfigure -backend-config="bucket=$(terraform_bucket)"

terraform-validate: terraform-init
	$(call header,Validate Terraform)
	terraform -chdir=$(terraform_dir) validate

terraform-plan: terraform-validate
	$(call header,Run Terraform Plan)
	terraform -chdir=$(terraform_dir) plan -input=false -refresh=true -var-file="$(terraform_tfvars)"

terraform-apply: terraform-validate
	$(call header,Run Terraform Apply)
	set -e
	terraform -chdir=$(terraform_dir) apply -auto-approve -input=false -var-file="$(terraform_tfvars)"
	terraform -chdir=$(terraform_dir) output -no-color -json >| $(terraform_dir)/output.json

terraform-destroy: terraform-validate
	$(call header,Run Terraform Apply)
	terraform -chdir=$(terraform_dir) apply -destroy -input=false -refresh=true -var-file="$(terraform_tfvars)"

terraform-clean:
	$(call header,Delete Terraform providers and state)
	-rm -rf $(terraform_dir)/.terraform $(terraform_dir)/.terraform.lock.hcl

terraform-show:
	terraform -chdir=$(terraform_dir) show -no-color | bat -l Terraform

terraform-list:
	terraform -chdir=$(terraform_dir) state list

terraform-state-recursive:
	gsutil ls -r gs://$(terraform_bucket)/**

terraform-state-versions:
	gsutil ls -a gs://$(terraform_bucket)/default.tfstate

terraform-state-unlock:
	gsutil rm gs://$(terraform_bucket)/default.tflock

terraform-version:
	$(call header,Terraform Version)
	terraform version

terraform-bucket:
	$(call header,Create Terraform state GCS bucket)
	set -e
	gcloud storage buckets create gs://$(terraform_bucket) --project=$(google_project) --location=$(google_region) --uniform-bucket-level-access || true
	gcloud storage buckets update gs://$(terraform_bucket) --versioning

###############################################################################
# Google GCE
###############################################################################

gce-status:
	$(call header,Google Compute Engine status)
	gcloud compute instances list --project=$(google_project)

gce-stop:
	$(call header,Stop Google Compute Engine instances)
	$(eval google_instances := $(shell gcloud compute instances list --project=$(google_project) --format='value(name)' --filter='zone:($(google_zone))'))
	if [ -n "$(google_instances)" ]; then
		for instance in $(google_instances); do
			echo "Stopping instance: $$instance in zone $(google_zone)"
			gcloud compute instances stop $$instance --project=$(google_project) --zone $(google_zone)
		done
	else
		echo "No instances found in zone $(google_zone)"
	fi

gce-exec: ansible-ready ## Execute remote command (cmd="...")
	@if [ -z "$(cmd)" ]; then \
		echo "$(red)Error: cmd required. Usage: make gce-exec cmd='pilot setup validate'$(reset)"; \
		exit 1; \
	fi
	$(call header,Execute on $(yellow)$(google_project)$(reset))
	ansible $(ansible_args) all -m shell -a "$(cmd)"

gce-ssh: $(ansible_ssh_key) ## SSH into GCE instance
	$(call header,SSH into GCE instance)
	ssh $(SSH_COMMON_ARGS) -i $(ansible_ssh_key) $(ansible_user)@$(shell jq -r '.ansible_hosts.value[0].dns' $(terraform_dir)/output.json)

gce-delete:
	$(call header,Delete Google Compute Engine instances)
	$(eval google_instances := $(shell gcloud compute instances list --project=$(google_project) --format='value(name)' --filter='zone:($(google_zone))'))
	if [ -n "$(google_instances)" ]; then
		for instance in $(google_instances); do
			echo "Deleting instance: $$instance in zone $(google_zone)"
			gcloud compute instances delete $$instance --project=$(google_project) --zone $(google_zone) --quiet
		done
	else
		echo "No instances found in zone $(google_zone)"
	fi

gce-start:
	$(call header,Start Google Compute Engine instances)
	$(eval google_instances := $(shell gcloud compute instances list --project=$(google_project) --format='value(name)' --filter='zone:($(google_zone))'))
	if [ -n "$(google_instances)" ]; then
		for instance in $(google_instances); do
			echo "Starting instance: $$instance in zone $(google_zone)"
			gcloud compute instances start $$instance --project=$(google_project) --zone $(google_zone)
		done
	else
		echo "No instances found in zone $(google_zone)"
	fi

###############################################################################
# Google Cloud
###############################################################################

google: google-config

google-auth:
	$(call header,Configure Google CLI)
	gcloud auth login --update-adc --no-launch-browser

google-logout:
	$(call header,Logout Google CLI)
	gcloud auth revoke --all

google-config:
	set -e
	gcloud auth application-default set-quota-project $(google_project)
	gcloud config set core/project $(google_project)
	gcloud config set compute/region $(google_region)
	gcloud config set compute/zone $(google_zone)
	gcloud config list

google-project:
	$(call header,Create Google Project)
	$(eval google_organization := $(shell pass lab5/google/organization_id))
	$(eval google_billing_account := $(shell pass lab5/google/billing_account))
	set -e
	echo -n "$(blue)Create Google Project $(yellow)$(google_project)$(reset)? $(green)(yes/no)$(reset)"
	read -p ": " answer && [ "$$answer" = "yes" ] || exit 1
	gcloud projects create $(google_project) --organization=$(google_organization)
	gcloud billing projects link $(google_project) --billing-account=$(google_billing_account)
	gcloud services enable cloudresourcemanager.googleapis.com --project=$(google_project)
	gcloud services enable compute.googleapis.com --project=$(google_project)
	$(MAKE) terraform-bucket


###############################################################################
# Colors and Headers
###############################################################################

TERM := xterm-256color

black := $$(tput setaf 0)
red := $$(tput setaf 1)
green := $$(tput setaf 2)
yellow := $$(tput setaf 3)
blue := $$(tput setaf 4)
magenta := $$(tput setaf 5)
cyan := $$(tput setaf 6)
white := $$(tput setaf 7)
reset := $$(tput sgr0)

define header
echo "$(blue)==> $(1) <==$(reset)"
endef

define var
echo "$(magenta)$(1)$(white): $(yellow)$(2)$(reset)"
endef

help:
	echo "$(blue)Usage: $(green)make [recipe]$(reset)"
	echo "$(blue)Recipes:$(reset)"
	awk 'BEGIN {FS = ":.*?## "; sort_cmd = "sort"} /^[a-zA-Z0-9_-]+:.*?## / \
	{ printf "  \033[33m%-15s\033[0m %s\n", $$1, $$2 | sort_cmd; } \
	END {close(sort_cmd)}' $(MAKEFILE_LIST)

prompt:
	printf "$(magenta)Continue $(white)? $(cyan)(yes/no)$(reset)"
	read -p ": " answer && [ "$$answer" = "yes" ] || exit 127

###############################################################################
# Errors
###############################################################################

ifeq ($(google_project),)
$(error ==> Missing Google Project. User Google Project folder <==)
endif

ifeq ($(shell which gcloud),)
$(error ==> Missing Google CLI https://cloud.google.com/sdk/docs/install <==)
endif

ifeq ($(shell which terraform),)
$(error ==> Missing terraform https://www.terraform.io/downloads <==)
endif

ifeq ($(shell which ansible),)
$(error ==> Missing ansible https://www.ansible.com/ <==)
endif
