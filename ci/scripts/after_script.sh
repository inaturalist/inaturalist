#!/bin/bash -e

source ./ci/scripts/guard.sh

echo "Stopping Talking Sphinx"
RAILS_ENV=test bundle exec rake --trace ts:stop
