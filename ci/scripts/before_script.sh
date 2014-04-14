#!/bin/bash -e

source ./ci/scripts/guard.sh

TRAVIS_PATCHES_DIR=${TRAVIS_PATCHES_DIR:=ci/patches}
RAILS_CONFIG_DIR=${RAILS_CONFIG_DIR:=config}

echo "Copying config files"
for ex in $RAILS_CONFIG_DIR/*.example; do
    f=$(basename "$ex" .example)
    p="$RAILS_CONFIG_DIR/$f"
    cp --backup "$ex" "$p"

    patch=$TRAVIS_PATCHES_DIR/$f.patch
    if [ -f "$patch" ]; then
        patch "$p" "$patch"
    fi
done

echo "Setting up DB and starting Talking Sphinx"
RAILS_ENV=test bundle exec rake --trace \
    db:setup \
    ts:conf \
    ts:index \
    ts:start
