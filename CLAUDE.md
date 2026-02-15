# CLAUDE.md

## Git Commands

- Do NOT use `git -C <path>` — run `git` commands without the `-C` flag
- The working directory is already the repository root

## Terraform

- Run `make terraform-plan` to validate and plan changes
- Run `make terraform-apply` to apply changes
- Target production with `google_project=mailpilot-org-prd1` (e.g. `make terraform-plan google_project=mailpilot-org-prd1`)

## Project Structure

- `terraform/main.tf` — provider config, org project variables and services
- `terraform/project-factory.tf` — child project creation (projects, APIs, VPC, subnets, buckets)
- `terraform/mailpilot-org-dev1.tfvars` — dev environment variables
- `terraform/mailpilot-org-prd1.tfvars` — prod environment variables
