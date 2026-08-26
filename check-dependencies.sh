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

# Smoke test for the dependency check, which is two commands with a handover directory between
# them: check-dependencies fetches candidate manifests, something else evaluates them, and
# add-validated-dependencies adds the ones that loaded.
#
# The evaluation step is deliberately not run here. It needs docker, this job runs inside a
# container, and it belongs to PackageList (.github/evaluate_manifests.sh) rather than to this
# repository. Running `swift package dump-package` directly instead would put third party manifest
# code back in a process holding SPI_API_TOKEN, which is the thing the split exists to prevent. So
# this stands in for that step by writing the markers it would have written.

set -eu

validator="swift run validator"
manifest_dir="$(mktemp -d)"
marker="evaluated"

# log the first 10 packages so we can compare the chunking
echo "Head of packages.json:"
curl -s https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/main/packages.json | head -11
echo "..."
echo

echo "=== fetching candidate manifests into $manifest_dir ==="
$validator check-dependencies \
    --spi-api-token "$SPI_API_TOKEN" \
    --input packages.json \
    --manifest-dir "$manifest_dir" \
    --max-check 25 --limit 1

echo
echo "=== handover layout ==="
find "$manifest_dir" | sort

if [ -z "$(find "$manifest_dir" -name 'Package*.swift' -print -quit)" ]; then
    echo
    echo "NOTE: no manifests were fetched, so the handover and add paths below prove nothing"
    echo "      beyond the two commands agreeing that the directory is empty."
fi

# The sign off is what tells add-validated-dependencies that the manifests were actually
# evaluated. Without it a directory nothing ever looked at is indistinguishable from one where
# nothing failed, so it has to refuse rather than add every candidate unchecked.
echo
echo "=== add-validated-dependencies must refuse an unevaluated handover ==="
# Matching the message, not just a non-zero exit. `swift run` returns non-zero for a build
# failure, a bad flag or a missing binary too, so exit status alone would report those as a
# passing refusal and the assertion would hold even with the check deleted. Matching text
# without quotes in it, because the thrown error reaches stderr with its quotes escaped.
refusal="$($validator add-validated-dependencies \
    --manifest-dir "$manifest_dir" \
    --input packages.json --output /dev/null 2>&1 || true)"

if ! echo "$refusal" | grep -q 'manifests were never evaluated'; then
    echo "FAILED: expected a refusal naming the missing '$marker' marker, got:"
    echo "$refusal"
    exit 1
fi
echo "... refused, as it should"

# Standing in for evaluate_manifests.sh: pretend every candidate loaded. Nothing here evaluates
# anything, so this says nothing about whether the manifests are valid - only that the two
# commands agree on the directory layout.
echo
echo "=== signing off as the evaluation step would, then adding ==="
touch "$manifest_dir/$marker"
$validator add-validated-dependencies \
    --manifest-dir "$manifest_dir" \
    --input packages.json --output packages.json

echo
echo "=== resulting packages.json ==="
head -11 packages.json

rm -rf "$manifest_dir"
