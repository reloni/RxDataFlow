set -e

echo $BUDDYBUILD_TEST_DIR
ls $BUDDYBUILD_TEST_DIR
bash <(curl -s https://codecov.io/bash) -J '^RxDataFlow$'
