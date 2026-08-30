#!/usr/bin/env bash

./scripts/install_homebrew.sh
brew tap uroybd/tap
brew install dotr bitwarden-cli
dotr deploy

