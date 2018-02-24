#!/bin/bash
set -e

curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --user
pip3 install awscli --upgrade --user
aws --version

sh Scripts/DownloadCacheFromS3.sh
