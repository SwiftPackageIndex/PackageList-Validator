# spi-validator

Validator for nightly PackageList validation.

## How PackageList's nightly job uses this

The validator does not evaluate manifests, instead `check-dependencies` fetches candidate manifests and stops. Then these manifests should be evaluated with `swift package dump-package` in an isolated container. Finally, `add-validated-dependencies` adds whichever ones loaded.

That split is why the dependency check is three commands rather than one. PackageList and PackageList-Validator agree on a directory layout for the manifests.

```mermaid
flowchart TD
    schedule["cron 0 6 * * *<br/>nightly.yml"] --> build

    subgraph build_validator["job: build_validator"]
        build["git clone PackageList-Validator<br/>swift build<br/><i>uploads the validator binary</i>"]
    end

    subgraph check_redirects["job: check_redirects"]
        redirects["validator check-redirects<br/>packages.json to redirect-checked.json<br/><i>drops redirects, dupes, dead repos</i>"]
    end

    subgraph check_dependencies["job: check_dependencies"]
        fetch["validator check-dependencies<br/>--input redirect-checked.json<br/>--manifest-dir DIR --limit 20<br/><i>asks the SPI API which deps are unindexed,<br/>fetches their manifests into DIR</i>"]
        evaluate["evaluate_manifests.sh DIR<br/>SPI_EVALUATION_MODE=report<br/><i>one container per package:<br/>swift package dump-package</i>"]
        add["validator add-validated-dependencies<br/>--manifest-dir DIR<br/>--input redirect-checked.json<br/>--output packages.json"]
        deny["validator apply-deny-list<br/>-p packages.json -d denylist.json"]
        pr["peter-evans/create-pull-request<br/><i>Nightly Updated Packages</i>"]
        fetch --> evaluate --> add --> deny --> pr
    end

    build --> redirects --> fetch

    classDef v fill:#dbeafe,stroke:#1e40af,color:#111827
    classDef p fill:#fef3c7,stroke:#92400e,color:#111827
    class redirects,fetch,add,deny v
    class schedule,build,evaluate,pr p
```

Blue is this repository, amber is PackageList.

### The handover directory

`--manifest-dir` is the interface between the two repositories.

```
DIR/
├── evaluated                     written by the script once it has run
├── <owner>_<repo>/
│   ├── manifests/Package*.swift  the only thing mounted into the container
│   ├── url                       which package these came from
│   └── failed                    written by the script if they did not load
└── ...
```

### Running it by hand

`check-dependencies` needs an `SPI_API_TOKEN` and a `GITHUB_TOKEN`; the evaluation step needs docker and a `SWIFT_IMAGE`.

```sh
mkdir -p /tmp/manifests

validator check-dependencies --spi-api-token "$SPI_API_TOKEN" \
    --input packages.json --manifest-dir /tmp/manifests --limit 3

SWIFT_IMAGE=swift:6.3-jammy SPI_EVALUATION_MODE=report \
    bash ../PackageList/.github/evaluate_manifests.sh /tmp/manifests

validator add-validated-dependencies --manifest-dir /tmp/manifests \
    --input packages.json --output /tmp/packages.json
```

## Prepare new release

- Run `make commit` (if there have been any code level changes)
- Push
- Merge to `main` for it to be picked up
