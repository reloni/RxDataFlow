#!/bin/bash
set -e

pip install --user awscli
export PATH=$PATH:$HOME/.local/bin

sh Scripts/DownloadCacheFromS3.sh
