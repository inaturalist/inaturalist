#!/bin/bash

# Install dependencies
brew update || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &
# Install git if you haven't already
brew install git &

# We use imagemagick for processing observation photos and profile pics
brew install imagemagick &

# We use exiftool for doing some photo metadata processing
brew install exiftool &

# We use ffmpeg to manipulate sound files
brew install ffmpeg &

# You will probably need postgres libraries on the host to compile the Ruby postgres gem
brew install libpq &

# The RGeo gem will need this
brew install geos &

# Docker and docker compose
brew install docker-compose & 

brew install postgresql

## RVM was not respecting the openssl-dir parameter, so we can use rbenv instead.
# rvm install $(cat .ruby-version) \
#   --autolibs=disable \
#   --with-openssl-dir=$(brew --prefix openssl@3) \
#   --with-readline-dir=$(brew --prefix readline)
# rvm use &

rbenv install
rbenv local $(cat .ruby-version)

# Install gems 
sudo gem install bundler -v 2.4.22 &
bundle install


# install and run webpack to generate necessary assets
nvm install

npm install

npm run webpack

rake inaturalist:generate_translations_js

# Customize the docker config
cp docker-compose.override.yml.example docker-compose.override.yml &

bundle config build.pg "--with-cflags=-I/opt/homebrew/opt/libpq/include --with-ldflags=-L/opt/homebrew/opt/libpq/lib" &
CFLAGS="-Wno-error=implicit-function-declaration" bundle
