.EXPORT_ALL_VARIABLES:
.ONESHELL:
.SILENT:

SHELL := bash
.SHELLFLAGS := -ec

MAKEFLAGS += --no-builtin-rules --no-builtin-variables

# §V8: prod-confirm gate. Pass `confirm=prd1` to skip interactive prompt.
define require_prd_confirm
if [ "$(google_project)" = "lab5-mailpilot-prd1" ] && [ "$(confirm)" != "prd1" ]; then
	printf 'Deploy to PROD (lab5-mailpilot-prd1)? Type "yes" to continue: '
	read _answer
	if [ "$$_answer" != "yes" ]; then
		echo "aborted: pass confirm=prd1 to skip prompt"
		exit 1
	fi
fi
endef

default: help

google_project ?= lab5-mailpilot-prd1
google_region ?= us-east1
google_zone ?= $(google_region)-b

git_root := $(shell git rev-parse --show-toplevel)
root_dir := $(git_root)
secrets_dir := $(root_dir)/secrets
config_dir := $(root_dir)/config/$(google_project)

venv_dir := $(root_dir)/.venv
venv_stamp := $(venv_dir)/.stamp
ansible := $(venv_dir)/bin/ansible
ansible_playbook := $(venv_dir)/bin/ansible-playbook
ansible_galaxy := $(venv_dir)/bin/ansible-galaxy
ansible_lint := $(venv_dir)/bin/ansible-lint

$(venv_stamp): pyproject.toml ansible/requirements.yml
	uv sync
	$(ansible_galaxy) collection install -r ansible/requirements.yml --force >/dev/null
	touch $@

venv: $(venv_stamp)

settings: ## Display settings
	echo "google_project: $(google_project)"
	echo "google_region:  $(google_region)"
	echo "google_zone:    $(google_zone)"
	echo "config_dir:     $(config_dir)"

lint: terraform-validate ansible-lint ## Run Terraform and Ansible linters

verify: ## Audit SPEC.md V1/V2/V6 invariants
	rc=0
	echo "==> V1: secrets/ committed plaintext check <=="
	plaintext=$$(git -C $(root_dir) ls-files secrets/ | grep -vE '\.gpg$$|^secrets/\.gpg_id$$|^secrets/\.gitignore$$|^secrets/makefile$$' || true)
	if [ -n "$$plaintext" ]; then
		echo "V1 FAIL: committed plaintext under secrets/:"
		echo "$$plaintext" | sed 's/^/  /'
		rc=1
	else
		echo "V1 OK"
	fi
	echo "==> V2: ansible inventory drift vs terraform-output.json <=="
	for proj_dir in $(root_dir)/config/*/; do
		proj=$$(basename $$proj_dir)
		out=$$proj_dir/terraform-output.json
		inv=$$proj_dir/ansible/inventory
		if [ ! -f "$$out" ]; then
			echo "  $$proj: skip (no terraform-output.json)"
			continue
		fi
		exp_names=$$(mktemp)
		act_names=$$(mktemp)
		jq -r '.ansible_hosts.value[].name' $$out | sort > $$exp_names
		find $$inv -maxdepth 1 -type f ! -name '.gitignore' -exec basename {} \; | sort > $$act_names
		if ! diff -q $$exp_names $$act_names >/dev/null 2>&1; then
			echo "V2 FAIL: $$proj inventory filenames drift"
			diff $$exp_names $$act_names | sed 's/^/  /' || true
			rc=1
			rm -f $$exp_names $$act_names
			continue
		fi
		rm -f $$exp_names $$act_names
		exp_pairs=$$(mktemp)
		jq -r '.ansible_hosts.value[] | "\(.name) \(.dns)"' $$out > $$exp_pairs
		drift=0
		while read -r name dns; do
			file=$$inv/$$name
			if [ ! -f "$$file" ] || [ "$$(cat $$file)" != "$$dns" ]; then
				echo "V2 FAIL: $$proj $$name content drift (expected $$dns)"
				drift=1
			fi
		done < $$exp_pairs
		rm -f $$exp_pairs
		if [ $$drift -eq 0 ]; then
			echo "  $$proj: OK"
		else
			rc=1
		fi
	done
	echo "==> V6: per-project files outside config/ <=="
	projects=$$(ls -1 $(root_dir)/config/ 2>/dev/null)
	if [ -z "$$projects" ]; then
		echo "V6 SKIP: no projects under config/"
	else
		pattern=$$(echo "$$projects" | paste -sd '|' -)
		stray=$$(git -C $(root_dir) ls-files terraform/ ansible/ | grep -E "($$pattern)" || true)
		if [ -n "$$stray" ]; then
			echo "V6 FAIL: per-project paths committed outside config/:"
			echo "$$stray" | sed 's/^/  /'
			rc=1
		else
			echo "V6 OK"
		fi
	fi
	exit $$rc

deploy: terraform-validate ## Deploy to lab5-mailpilot-prd1 (prod requires confirm=prd1)
	$(require_prd_confirm)
	set -e
	echo "==> Plan check for $(google_project) <=="
	rc=0
	terraform -chdir=$(terraform_dir) plan -detailed-exitcode -input=false -refresh=true -var-file="$(terraform_tfvars)" -compact-warnings || rc=$$?
	if [ $$rc -eq 2 ]; then
		echo ""
		echo "Terraform changes pending. Review plan above, then run:"
		echo "  make terraform-apply"
		echo "  make deploy"
		exit 1
	elif [ $$rc -ne 0 ]; then
		exit $$rc
	fi
	echo ""
	echo "==> Deploy $(google_project) (no infra changes) <=="
	$(MAKE) gce-configure
	$(MAKE) leadpilot-deploy
	$(MAKE) mailpilot-deploy

# Ansible

ansible_dir := $(root_dir)/ansible
ansible_user := ubuntu
ansible_inventory := $(config_dir)/ansible/inventory
ansible_ssh_key := $(secrets_dir)/ssh.key
ansible_signing_key := $(secrets_dir)/github-signing.key
ansible_args := --inventory $(ansible_inventory) --user $(ansible_user) --private-key $(ansible_ssh_key) --extra-vars ansible_python_interpreter='/usr/bin/python3.12'

SSH_COMMON_ARGS := -o StrictHostKeyChecking=no

$(ansible_ssh_key):
	gpg $@.gpg && chmod 600 $@

$(ansible_signing_key):
	gpg $@.gpg && chmod 600 $@

ansible-inventory:
	find $(ansible_inventory) -maxdepth 1 -type f ! -name '.gitignore' -delete
	jq -r '.ansible_hosts.value[] | "\(.name) \(.dns) \(.ip)"' $(terraform_output) | while read -r name dns ip; do
	    echo "$${dns}" > $(ansible_inventory)/$$name
	done

ansible-ready: $(venv_stamp) ansible-inventory $(ansible_ssh_key) $(ansible_signing_key)

ansible-lint: $(venv_stamp)
	$(ansible_lint) $(ansible_dir)

# VM Configuration

gce-configure: ansible-ready
	TAILSCALE_AUTH_KEY=$$(gpg -d $(secrets_dir)/TAILSCALE_AUTH_KEY.gpg 2>/dev/null) || true
	POSTGRESQL_REMOTE_PASSWORD=$$(gpg -d $(secrets_dir)/POSTGRESQL_REMOTE_PASSWORD.gpg 2>/dev/null) || true
	if [ -z "$$TAILSCALE_AUTH_KEY" ] || [ -z "$$POSTGRESQL_REMOTE_PASSWORD" ]; then
		echo "Error: failed to decrypt secrets in $(secrets_dir) (is gpg-agent unlocked?)"
		exit 1
	fi
	for i in 1 2 3 4 5; do
		$(ansible) all --module-name ping $(ansible_args) && break ||
		if [ $$i -eq 5 ]; then exit 1; else sleep 6; fi;
	done
	$(ansible_playbook) $(ansible_args) \
		--extra-vars "tailscale_auth_key=$$TAILSCALE_AUTH_KEY postgresql_remote_password=$$POSTGRESQL_REMOTE_PASSWORD" \
		ansible/playbook-vm-config.yaml
	$(MAKE) -C $(secrets_dir) clean

# LeadPilot Deployment

leadpilot-deploy: ansible-ready
	$(require_prd_confirm)
	leadpilot_version='$(leadpilot_version)'
	GITHUB_TOKEN=$$(gpg -d $(secrets_dir)/GITHUB_TOKEN.gpg 2>/dev/null) || true
	if [ -z "$$GITHUB_TOKEN" ]; then
		echo "Error: failed to decrypt $(secrets_dir)/GITHUB_TOKEN.gpg (is gpg-agent unlocked?)"
		exit 1
	fi
	if [ -z "$$leadpilot_version" ]; then
		leadpilot_version=$$(curl -fsSL -H "Authorization: Bearer $$GITHUB_TOKEN" https://api.github.com/repos/kborovik/leadpilot/releases/latest 2>/dev/null | jq -r '.tag_name // empty' | sed 's/^v//') || true
	fi
	if [ -z "$$leadpilot_version" ]; then
		echo "Error: could not detect latest leadpilot release. Pass explicitly: make leadpilot-deploy leadpilot_version=X.Y.Z"
		exit 1
	fi
	echo "==> Deploy LeadPilot v$$leadpilot_version to $(google_project) <=="
	$(ansible_playbook) $(ansible_args) \
		--extra-vars "leadpilot_version=$$leadpilot_version leadpilot_github_token=$$GITHUB_TOKEN" \
		ansible/playbook-leadpilot-deploy.yaml
	$(MAKE) -C $(secrets_dir) clean

leadpilot-status: ansible-ready
	$(ansible) $(ansible_args) all -m shell -a \
		"leadpilot --version; echo '---'; leadpilot status; echo '---'; crontab -l | grep leadpilot || true"

# MailPilot Deployment

mailpilot-deploy: ansible-ready
	$(require_prd_confirm)
	mailpilot_version='$(mailpilot_version)'
	GITHUB_TOKEN=$$(gpg -d $(secrets_dir)/GITHUB_TOKEN.gpg 2>/dev/null) || true
	if [ -z "$$GITHUB_TOKEN" ]; then
		echo "Error: failed to decrypt $(secrets_dir)/GITHUB_TOKEN.gpg (is gpg-agent unlocked?)"
		exit 1
	fi
	if [ -z "$$mailpilot_version" ]; then
		mailpilot_version=$$(curl -fsSL -H "Authorization: Bearer $$GITHUB_TOKEN" https://api.github.com/repos/kborovik/mailpilot/releases/latest 2>/dev/null | jq -r '.tag_name // empty' | sed 's/^v//') || true
	fi
	if [ -z "$$mailpilot_version" ]; then
		echo "Error: could not detect latest mailpilot release. Pass explicitly: make mailpilot-deploy mailpilot_version=X.Y.Z"
		exit 1
	fi
	echo "==> Deploy MailPilot v$$mailpilot_version to $(google_project) <=="
	$(ansible_playbook) $(ansible_args) \
		--extra-vars "mailpilot_version=$$mailpilot_version mailpilot_github_token=$$GITHUB_TOKEN" \
		ansible/playbook-mailpilot-deploy.yaml
	$(MAKE) -C $(secrets_dir) clean

mailpilot-status: ansible-ready
	$(ansible) $(ansible_args) all -m shell -a \
		"mailpilot --version; echo '---'; mailpilot status"

# Terraform

terraform_dir := $(root_dir)/terraform
terraform_tfvars := $(config_dir)/terraform.tfvars
terraform_output := $(config_dir)/terraform-output.json
terraform_bucket := terraform-$(google_project)

CLOUDFLARE_API_TOKEN = $(shell gpg -d $(secrets_dir)/CLOUDFLARE_API_TOKEN.gpg 2>/dev/null)

terraform-config:
	ln -fs $(terraform_tfvars) $(terraform_dir)/terraform.tfvars

terraform-fmt: terraform-config
	terraform -chdir=$(terraform_dir) fmt -check -recursive

terraform-init: terraform-fmt
	terraform -chdir=$(terraform_dir) init -upgrade -reconfigure -backend-config="bucket=$(terraform_bucket)"

terraform-validate: terraform-init
	terraform -chdir=$(terraform_dir) validate

terraform-plan: terraform-validate
	terraform -chdir=$(terraform_dir) plan -input=false -refresh=true -var-file="$(terraform_tfvars)"

terraform-apply: terraform-validate
	set -e
	terraform -chdir=$(terraform_dir) apply -auto-approve -input=false -var-file="$(terraform_tfvars)"
	terraform -chdir=$(terraform_dir) output -no-color -json >| $(terraform_output)

terraform-clean:
	-rm -rf $(terraform_dir)/.terraform $(terraform_dir)/.terraform.lock.hcl

# Google GCE

gce-status:
	gcloud compute instances list --project=$(google_project)

gce-stop:
	$(eval google_instances := $(shell gcloud compute instances list --project=$(google_project) --format='value(name)' --filter='zone:($(google_zone))'))
	for instance in $(google_instances); do
		gcloud compute instances stop $$instance --project=$(google_project) --zone $(google_zone)
	done

gce-start:
	$(eval google_instances := $(shell gcloud compute instances list --project=$(google_project) --format='value(name)' --filter='zone:($(google_zone))'))
	for instance in $(google_instances); do
		gcloud compute instances start $$instance --project=$(google_project) --zone $(google_zone)
	done

gce-exec: ansible-ready
	@if [ -z "$(cmd)" ]; then echo "Error: cmd required. Usage: make gce-exec cmd='...'"; exit 1; fi
	$(ansible) $(ansible_args) all -m shell -a "$(cmd)"

gce-ssh: $(ansible_ssh_key)
	ssh $(SSH_COMMON_ARGS) -i $(ansible_ssh_key) $(ansible_user)@$(shell jq -r '.ansible_hosts.value[0].dns' $(terraform_output))

# Google Cloud

google-auth:
	gcloud auth login --update-adc --no-launch-browser

google-config:
	set -e
	gcloud auth application-default set-quota-project $(google_project)
	gcloud config set core/project $(google_project)
	gcloud config set compute/region $(google_region)
	gcloud config set compute/zone $(google_zone)
	gcloud config list

help:
	echo "Usage: make [recipe]"
	echo "Recipes:"
	awk 'BEGIN {FS = ":.*?## "; sort_cmd = "sort"} /^[a-zA-Z0-9_-]+:.*?## / \
	{ printf "  %-12s %s\n", $$1, $$2 | sort_cmd; } \
	END {close(sort_cmd)}' $(MAKEFILE_LIST)

# Errors

ifeq ($(google_project),)
$(error Missing google_project)
endif

ifeq ($(shell which gcloud),)
$(error Missing gcloud https://cloud.google.com/sdk/docs/install)
endif

ifeq ($(shell which terraform),)
$(error Missing terraform https://www.terraform.io/downloads)
endif

ifeq ($(shell which uv),)
$(error Missing uv https://docs.astral.sh/uv/)
endif
