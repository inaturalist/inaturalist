FROM ruby:3.0

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client-13 libgeos-dev libgeos++-dev gdal-bin proj-bin libproj-dev imagemagick exiftool ffmpeg libcurl4 libcurl4-openssl-dev

RUN useradd -ms /bin/bash inaturalist

WORKDIR /code

RUN chown inaturalist:inaturalist /code

USER inaturalist
COPY --chown=inaturalist:inaturalist Gemfile /code/Gemfile
COPY --chown=inaturalist:inaturalist Gemfile.lock /code/Gemfile.lock

RUN gem install bundler
RUN bundle install --verbose

RUN mkdir -p /code/config
COPY --chown=inaturalist:inaturalist . /code
RUN cp /code/config/config.yml.example /code/config/config.yml
RUN cp /code/config/database.yml.example /code/config/database.yml
RUN cp /code/config/secrets.yml.example /code/config/secrets.yml

# Add a script to be executed every time the container starts.
COPY --chown=inaturalist:inaturalist entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
# EXPOSE 3000

# Configure the main process to run when running the image
CMD "rspec"

