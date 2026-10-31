#!/bin/sh
set -e
brew install swiftlint
cd "$CI_PRIMARY_REPOSITORY_PATH"
swiftlint lint --strict
