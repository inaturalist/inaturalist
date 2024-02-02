FROM ruby:3.0 as base

ENV RAILS_ENV=development

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client-13 libgeos-dev libgeos++-dev gdal-bin proj-bin libproj-dev imagemagick exiftool ffmpeg libcurl4 libcurl4-openssl-dev zip openjdk-17-jdk

RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -\
  && apt-get update -qq && apt-get install -qq --no-install-recommends \
    nodejs \
  && apt-get upgrade -qq \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash inaturalist

WORKDIR /code

RUN chown inaturalist:inaturalist /code

USER inaturalist
COPY --chown=inaturalist:inaturalist Gemfile /code/Gemfile
COPY --chown=inaturalist:inaturalist Gemfile.lock /code/Gemfile.lock

RUN gem install bundler
RUN bundle install --verbose

COPY --chown=inaturalist:inaturalist . /code/

RUN rm -rf node_modules

RUN npm install

COPY --chown=inaturalist:inaturalist config/config.docker.yml /code/config/config.yml
COPY --chown=inaturalist:inaturalist config/database.docker.yml /code/config/database.yml
COPY --chown=inaturalist:inaturalist config/secrets.docker.yml /code/config/secrets.yml
COPY --chown=inaturalist:inaturalist config/smtp.docker.yml /code/config/smtp.yml

RUN npm run webpack

FROM base as assets

COPY --chown=inaturalist:inaturalist config/database.docker.assets.yml /code/config/database.yml

RUN RAILS_ENV=production SECRET_KEY_BASE=1 PRECOMPILE_ASSETS=true rake inaturalist:generate_translations_js

RUN RAILS_ENV=production SECRET_KEY_BASE=1 PRECOMPILE_ASSETS=true rake assets:precompile

FROM base as production

COPY --from=assets /code/public/assets /code/public/assets

RUN mkdir /code/public/attachments
RUN chown inaturalist:inaturalist /code/public/attachments

EXPOSE 3000

CMD "./docker/init_docker_rails_app.sh"
