# open24-iac

Infrastructure-as-code for Open24, structured for multiple cloud providers.

## Current status
- `do` stack is active (DigitalOcean)
- `aws` stack is scaffolded for future use

## Folder structure
```text
open24-iac/
  Makefile
  Makefile.do
  Makefile.aws
  stacks/
    do/
      versions.tf
      main.tf
      variables.tf
      outputs.tf
    aws/
      versions.tf
      main.tf
      variables.tf
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
    terraform.tfvars
```

This keeps sensitive values local and out of infra code.

## Make usage
Two provider-specific makefiles are provided.

### DigitalOcean
```sh
make -f Makefile.do init
make -f Makefile.do plan
make -f Makefile.do apply
make -f Makefile.do destroy
```

### AWS (scaffold)
```sh
make -f Makefile.aws init
make -f Makefile.aws plan
make -f Makefile.aws apply
make -f Makefile.aws destroy
```

Optional wrapper shortcuts:
```sh
make do-plan
make do-apply
make aws-plan
```

## Notes
- Run `init` before `plan/apply` for each stack.
- `Makefile.do` and `Makefile.aws` both validate required local config files before running Terraform.
