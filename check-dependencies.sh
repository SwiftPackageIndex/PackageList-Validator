#!/bin/sh

# Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

validator="swift run validator"

# log the first 10 packages so we can compare the chunking
echo "Head of packages.json:"
curl -s https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json | head -11
echo "..."
echo

$validator check-dependencies \
    --spi-api-token "$SPI_API_TOKEN" \
    -i packages.json -o packages.json \
    --max-check 1
