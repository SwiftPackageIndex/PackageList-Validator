#!/bin/sh

#validator="xcrun swift run validator"
validator="./validator"


$validator check-dependencies --use-package-list -o packages.json -l 10
cat packages.json
