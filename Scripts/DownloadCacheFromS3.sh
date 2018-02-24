#!/bin/bash
set -e

aws s3 sync s3://app-build-caches/RxDataFlow/Carthage/Build/iOS ./Carthage/Build/iOS/
