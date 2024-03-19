#!/bin/bash

rake inaturalist:generate_translations_js

rake assets:precompile

rails s -b 0.0.0.0
