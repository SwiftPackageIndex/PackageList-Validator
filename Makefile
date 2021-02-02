.DEFAULT_GOAL := install


VERSION := $(shell git describe --always --tags --dirty)
VERSION_FILE = Sources/ValidatorCore/Version.swift
XCODE="/Applications/Xcode_12.app"

commit: install
	git commit -a -m "make commit: $(VERSION)"


install: version
	env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release --arch x86_64
	cp "$(shell env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release --show-bin-path)"/validator .
	@# reset version file
	@git checkout $(VERSION_FILE)


test:
	swift test --parallel


version:
	@# avoid tracking changes for file:
	@git update-index --assume-unchanged $(VERSION_FILE)
	@echo VERSION: $(VERSION)
	@echo "public let AppVersion = \"$(VERSION)\"" > $(VERSION_FILE)
