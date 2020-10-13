#!/bin/sh

#validator="xcrun swift run validator"
validator="./validator"


#curl -O "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json"

$validator check-redirects --use-package-list -o packages.json -l 10
cat packages.json
