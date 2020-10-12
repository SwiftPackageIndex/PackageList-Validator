#!/bin/sh

#validator="xcrun swift run validator"
validator="./validator"

#https://api.github.com/repos/0xdeadp00l/bech32 \
#https://api.github.com/repos/1024jp/GzipSwift \
#https://api.github.com/repos/1024jp/WFColorCode \
#https://api.github.com/repos/10clouds/ParticlePullToRefresh-iOS \
#https://api.github.com/repos/123flo321/pogoprotos-swift \

urls="https://api.github.com/repos/0111b/Conf \
https://api.github.com/repos/0111b/JSONDecoder-Keypath \
https://api.github.com/repos/0x7fs/countedset \
https://api.github.com/repos/0xacdc/XCFSodium \
https://api.github.com/repos/1904labs/ios-test-utils \
https://github.com/swift-aws/aws-sdk-swift
"


$validator check-redirects $urls
