.PHONY: do-help do-init do-plan do-apply do-destroy aws-help aws-init aws-plan aws-apply aws-destroy aws-ws-help aws-ws-init aws-ws-list aws-ws-new aws-ws-select aws-ws-delete aws-ws-plan aws-ws-apply aws-ws-destroy aws-ws-output

# ⚠️ DEPRECATED — Use Makefile.aws-ws with WORKSPACE= instead.
# ── DigitalOcean targets ────────────────────────────────────────

do-help:
	@$(MAKE) -f Makefile.do help

do-init:
	@$(MAKE) -f Makefile.do init

do-plan:
	@$(MAKE) -f Makefile.do plan

do-apply:
	@$(MAKE) -f Makefile.do apply

do-destroy:
	@$(MAKE) -f Makefile.do destroy

# ── AWS legacy targets (deprecated — use aws-ws-* instead) ─────

aws-help:
	@$(MAKE) -f Makefile.aws help

aws-init:
	@$(MAKE) -f Makefile.aws init

aws-plan:
	@$(MAKE) -f Makefile.aws plan

aws-apply:
	@$(MAKE) -f Makefile.aws apply

aws-destroy:
	@$(MAKE) -f Makefile.aws destroy


# ✅ ── AWS Workspace targets ───────────────────────────────────────
# Usage: make aws-ws-<target> WORKSPACE=<name>

aws-ws-help:
	@$(MAKE) -f Makefile.aws-ws help

aws-ws-init:
	@$(MAKE) -f Makefile.aws-ws init

aws-ws-list:
	@$(MAKE) -f Makefile.aws-ws ws-list

aws-ws-new:
	@$(MAKE) -f Makefile.aws-ws ws-new WORKSPACE=$(WORKSPACE)

aws-ws-select:
	@$(MAKE) -f Makefile.aws-ws ws-select WORKSPACE=$(WORKSPACE)

aws-ws-delete:
	@$(MAKE) -f Makefile.aws-ws ws-delete WORKSPACE=$(WORKSPACE)

aws-ws-plan:
	@$(MAKE) -f Makefile.aws-ws plan WORKSPACE=$(WORKSPACE)

aws-ws-apply:
	@$(MAKE) -f Makefile.aws-ws apply WORKSPACE=$(WORKSPACE)

aws-ws-destroy:
	@$(MAKE) -f Makefile.aws-ws destroy WORKSPACE=$(WORKSPACE)

aws-ws-output:
	@$(MAKE) -f Makefile.aws-ws output WORKSPACE=$(WORKSPACE)
