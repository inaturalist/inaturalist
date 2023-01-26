#!/bin/bash
set -e

RAILS_ENV=test rake db:drop
RAILS_ENV=test rake db:setup
RAILS_ENV=test rake db:migrate
RAILS_ENV=test rake inaturalist:generate_translations_js

# exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
