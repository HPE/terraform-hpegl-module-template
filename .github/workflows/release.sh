#!/bin/sh
# (c) Copyright 2022 Hewlett Packard Enterprise Development LP

# Install dependencies
sudo apt update
sudo apt-get install bash git curl jq nodejs npm
sudo npm install -g semver

.github/workflows/releaseortag.sh
