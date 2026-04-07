# open24-iac

Infrastructure-as-code for Open24, structured for multiple cloud providers.

## Current status
- `do` stack is active — **dev** environment (DigitalOcean droplet)
- `aws` stack is active — **uat** environment (EC2 + RDS), **prod** planned

## Environments

| Environment | Branch | Infrastructure | Domain |
|-------------|--------|---------------|--------|
| dev | `dev` | DO droplet | open24.bbst.org / open24api.bbst.org |
| uat | `uat` | AWS EC2 + RDS | open247.bbst.org / open247api.bbst.org |
| prod | `main` | AWS (placeholder) | TBD |

## Folder structure
```text
open24-iac/
  Makefile            # Delegates to provider-specific makefiles
  Makefile.do         # DigitalOcean (dev)
  Makefile.aws        # AWS — default workspace (DEPRECATED, use aws-ws)
  Makefile.aws-ws     # AWS — workspace-aware (recommended)
  stacks/
    do/
      versions.tf
      main.tf
      variables.tf
      outputs.tf
    aws/
      versions.tf
      main.tf          # All resources parameterized with var.environment
      variables.tf     # Includes `environment` variable (no default — must be set in tfvars)
      outputs.tf
```

## Local-only config location
Terraform backend config and tfvars live outside this repo in:

```text
../open24-config-stay-local/tf/
  do/
    backend.hcl
    terraform.tfvars
  aws/
    backend.hcl
    terraform.tfvars    # Default/fallback tfvars
    uat.tfvars          # UAT-specific overrides (current AWS infra)
```

This keeps sensitive values local and out of infra code.

## Make usage

### DigitalOcean (dev)
```sh
make do-init
make do-plan
make do-apply
make do-destroy
```

### AWS — default workspace (DEPRECATED)

> **Use `aws-ws-*` targets instead.** These legacy targets operate on the default
> Terraform workspace only and will be removed in a future cleanup.

```sh
make aws-init
make aws-plan
make aws-apply
make aws-destroy
```

### AWS — workspace-aware (recommended) ✅

Workspace management:
```sh
make aws-ws-list                        # List all workspaces
make aws-ws-new WORKSPACE=uat           # Create new workspace
make aws-ws-select WORKSPACE=uat        # Switch to workspace
make aws-ws-delete WORKSPACE=old-env    # Delete a workspace
```

Plan/apply (auto-selects workspace, uses `<WORKSPACE>.tfvars` if it exists):
```sh
make aws-ws-plan    WORKSPACE=uat       # Plan against UAT
make aws-ws-apply   WORKSPACE=uat       # Apply UAT changes
make aws-ws-destroy WORKSPACE=uat       # Destroy UAT infra
make aws-ws-output  WORKSPACE=uat       # Show outputs
```

Tfvars resolution: if `../open24-config-stay-local/tf/aws/uat.tfvars` exists, it's used automatically. Otherwise falls back to `terraform.tfvars`.

### Spinning up an ephemeral environment
```sh
# 1. Create a new workspace
make aws-ws-new WORKSPACE=test-feature-x

# 2. Create tfvars (copy uat.tfvars, change domains/passwords)
cp ../open24-config-stay-local/tf/aws/uat.tfvars \
   ../open24-config-stay-local/tf/aws/test-feature-x.tfvars
# Edit test-feature-x.tfvars: change environment, domains, db_password

# 3. Plan and apply
make aws-ws-plan  WORKSPACE=test-feature-x
make aws-ws-apply WORKSPACE=test-feature-x

# 4. When done, tear down
make aws-ws-destroy WORKSPACE=test-feature-x
make aws-ws-delete  WORKSPACE=test-feature-x
```

## Environment-specific behavior (Terraform)

| Setting | dev (DO) | uat (AWS) | prod (AWS) |
|---------|----------|-----------|------------|
| DB backups | N/A (managed DO) | Disabled (`backup_retention_period=0`) | **7 days** |
| Final snapshot on destroy | N/A | Skipped | **Required** |
| Multi-AZ | N/A | No | No |

## CI/CD

GitHub Actions workflows deploy automatically on push:

| Branch | Deploys to | Workflow |
|--------|-----------|----------|
| `dev` | DO droplet (dev) | `deploy.yml` |
| `uat` | AWS EC2 (uat) | `deploy.yml` |
| `main` | — (prod placeholder) | No deploy triggered |

Workflows use **GitHub Environments** for secret isolation. Each environment has normalized secret names (`REMOTE_HOST`, `REMOTE_USERNAME`, `REMOTE_SSH_PRIVATE_KEY`, `REMOTE_APP_PATH`/`REMOTE_BFF_PATH`) plus env-specific config secrets.

Manual deploy via `workflow_dispatch` is also available with an environment selector dropdown.

## Notes
- Run `init` before `plan/apply` for each stack.
- `Makefile.do` and `Makefile.aws-ws` both validate required local config files before running Terraform.
- AWS resource names are parameterized with `var.environment` (e.g., `open24-uat-vpc`, `open24-uat-pg`).
- Each workspace **must** have a matching `<WORKSPACE>.tfvars` with `environment` set — there is no default. Without it, Terraform will error or fall back to `terraform.tfvars` which may target the wrong environment.
- `Makefile.aws` (non-workspace) is deprecated; use `aws-ws-*` targets instead.