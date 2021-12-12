# spi-validator

Validator for nightly PackageList validation.

NB: the Swift version the validator is compiled with does not affect the Swift version that's being used to dump package details. At runtime, it will use the the system's installed Swift version to run `swift package dump-packge`, and this version may be newer than the one `validator` has been compiled with.

## Prepare new release

- Run `make commit` (if there have been any code level changes)
- Push
- Merge to `main` for it to be picked up
