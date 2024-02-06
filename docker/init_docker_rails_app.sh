#!/bin/bash

rake inaturalist:generate_translations_js

rake assets:precompile
