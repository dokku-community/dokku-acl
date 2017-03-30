shellcheck:
ifeq ($(shell shellcheck > /dev/null 2>&1 ; echo $$?),127)
ifeq ($(shell uname),Darwin)
	brew install shellcheck
else
	sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty-backports main restricted universe multiverse'
	sudo apt-get update -qq && sudo apt-get install -qq -y shellcheck
endif
endif

bats:
ifeq ($(shell bats > /dev/null 2>&1 ; echo $$?),127)
ifeq ($(shell uname),Darwin)
	brew install shellcheck
else
	sudo add-apt-repository ppa:duggan/bats --yes
	sudo apt-get update -qq && sudo apt-get install -qq -y bats
endif
endif

ci-dependencies: shellcheck bats

lint:
	@echo linting...
	@$(QUIET) find ./ -maxdepth 1 -not -path '*/\.*' | xargs file | egrep "shell|bash" | awk '{ print $$1 }' | sed 's/://g' | xargs shellcheck

unit-tests:
	@echo running unit tests...
	@$(QUIET) bats tests

setup:
	bash tests/setup.sh
	$(MAKE) ci-dependencies

test: setup lint unit-tests
