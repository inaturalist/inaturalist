FROM ruby:3.0

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client-13 libgeos-dev libgeos++-dev gdal-bin proj-bin libproj-dev imagemagick exiftool ffmpeg libcurl4 libcurl4-openssl-dev zip

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

COPY --chown=inaturalist:inaturalist package.json /code/package.json
COPY --chown=inaturalist:inaturalist package-lock.json /code/package-lock.json
RUN npm install

COPY --chown=inaturalist:inaturalist config /code/config

RUN cp /code/config/config.yml.example /code/config/config.yml
RUN cp /code/config/database.yml.example /code/config/database.yml
RUN cp /code/config/secrets.yml.example /code/config/secrets.yml

COPY --chown=inaturalist:inaturalist app/assets /code/app/assets
COPY --chown=inaturalist:inaturalist app/webpack /code/app/webpack
RUN npm run webpack

COPY --chown=inaturalist:inaturalist . /code

# Add a script to be executed every time the container starts.
COPY --chown=inaturalist:inaturalist entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
# EXPOSE 3000

# Configure the main process to run when running the image
CMD "rspec"
