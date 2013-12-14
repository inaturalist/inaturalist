#!/bin/bash -e

source ./ci/scripts/guard.sh

if [ -z "$SPEC_DIR" ]; then
    echo "SPEC_DIR environment variable missing" 1>&2
    exit 1
elif [ \! -d "$SPEC_DIR" ]; then
    echo "Spec directory not found: $SPEC_DIR" 1>&2
    exit 1
fi

echo "Executing rspec for $SPEC_DIR"
RAILS_ENV=test xvfb-run bundle exec rspec --format d "$SPEC_DIR"
