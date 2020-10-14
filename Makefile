XCODE="/Applications/Xcode_12.app"

install:
	env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release
	cp "$(shell env DEVELOPER_DIR=$(XCODE) xcrun swift build -c release --show-bin-path)"/validator .

test:
	swift test --parallel
