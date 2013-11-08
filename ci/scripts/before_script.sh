#!/bin/bash -e

source ./ci/scripts/guard.sh

TRAVIS_CONFIG_DIR=${TRAVIS_CONFIG_DIR:=ci/conf}
RAILS_CONFIG_DIR=${RAILS_CONFIG_DIR:=config}

echo "Copying config files"
cp $TRAVIS_CONFIG_DIR/* $RAILS_CONFIG_DIR/

echo "Setting up DB and starting Talking Sphinx"
RAILS_ENV=test bundle exec rake --trace \
    db:setup \
    ts:conf \
    ts:index \
    ts:start
