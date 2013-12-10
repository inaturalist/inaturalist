#!/bin/bash -e

source ./ci/scripts/guard.sh

echo "Executing rspec"
RAILS_ENV=test xvfb-run bundle exec rspec --format d spec
