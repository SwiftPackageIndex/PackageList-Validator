# Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

.DEFAULT_GOAL := install


VERSION := $(shell git describe --always --tags --dirty)
VERSION_FILE = Sources/ValidatorCore/Version.swift
XCODE="/Applications/Xcode_13.2.1.app"

commit: install
	git commit -a -m "make commit: $(VERSION)"


install: version
	env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release --arch x86_64
	cp "$(shell env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release --arch x86_64 --show-bin-path)"/validator .
	@# reset version file
	@git checkout $(VERSION_FILE)


test:
	swift test --parallel


version:
	@# avoid tracking changes for file:
	@git update-index --assume-unchanged $(VERSION_FILE)
	@echo VERSION: $(VERSION)
	@echo "public let AppVersion = \"$(VERSION)\"" > $(VERSION_FILE)
