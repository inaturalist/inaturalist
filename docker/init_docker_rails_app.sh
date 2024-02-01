#!/bin/bash

if [ ! -f "/code/app/assets/javascripts/i18n/translations/en.js" ]; then
	rake inaturalist:generate_translations_js
fi

rake assets:precompile

rails s -b 0.0.0.0
