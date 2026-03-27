.PHONY: do-help do-init do-plan do-apply do-destroy aws-help aws-init aws-plan aws-apply aws-destroy

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
