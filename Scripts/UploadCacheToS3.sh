#!/bin/bash
set -e

aws s3 sync ./Carthage/Build/iOS/ s3://app-build-caches/RxDataFlow/Carthage/Build/iOS
