set -e

bash <(curl -s https://codecov.io/bash) -J '^RxDataFlow$' -t $CODECOV_TOKEN
