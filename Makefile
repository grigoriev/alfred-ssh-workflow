WORKFLOW    := SSH.alfredworkflow
UPDATER_URL := https://github.com/grigoriev/alfred-workflow-updater/releases/latest/download/update.sh
SCRIPTS     := src/ssh.sh src/hosts.sh
EXCLUDES    := '.git/*' '.github/*' '.gitignore' 'Makefile' '$(WORKFLOW)'

.PHONY: all build updater verify-updater test lint clean

all: build

# Fetch the shared updater at build time (not stored in git)
updater:
	curl -sfL $(UPDATER_URL) -o src/update.sh
	chmod +x src/update.sh

# Confirm the fetched updater runs and reports an available update
verify-updater: updater
	@out=$$(alfred_workflow_version=0.0.1 update_repo=grigoriev/alfred-ssh-workflow update_asset=$(WORKFLOW) bash src/update.sh); \
	echo "$$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["items"], d'; \
	echo "$$out" | grep -q '"title":"Update to v'; \
	echo "updater OK"

# Build the .alfredworkflow bundle
build: verify-updater
	rm -f $(WORKFLOW)
	zip -qr $(WORKFLOW) . -x $(EXCLUDES)
	unzip -l $(WORKFLOW) | grep -q 'src/update.sh'
	@echo "built $(WORKFLOW)"

test:
	bats tests

lint:
	shellcheck -x --severity=warning $(SCRIPTS)

clean:
	rm -f $(WORKFLOW) src/update.sh
