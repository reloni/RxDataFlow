#!/bin/bash
set -e

/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
brew install python3

pip3 install awscli --upgrade --user
aws --version

sh Scripts/DownloadCacheFromS3.sh
