# make verify is the single entry point for humans, agents and CI.
SOURCES := Sources Tests Plugins Package.swift

.PHONY: verify verify-fast format format-check lint debt build test fence app

verify: format-check lint debt build test fence app

# Pre-commit subset: no app packaging, no fence proof.
verify-fast: format-check lint debt test

format:
	swift format -i -r $(SOURCES)

format-check:
	swift format lint --strict -r $(SOURCES)

lint:
	swiftlint lint --quiet --strict

debt:
	python3 scripts/check-debt.py

build:
	swift build

test:
	swift test --quiet

fence:
	scripts/prove-fence.sh

app:
	scripts/package-app.sh debug >/dev/null
