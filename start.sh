#!/bin/bash
make services
bundle exec rails s & npm run webpack-watch
