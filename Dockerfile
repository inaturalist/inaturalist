FROM ruby:3.0

ENV RAILS_ENV=development

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client-13 libgeos-dev libgeos++-dev gdal-bin proj-bin libproj-dev imagemagick exiftool ffmpeg libcurl4 libcurl4-openssl-dev zip openjdk-17-jdk

RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -\
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

COPY --chown=inaturalist:inaturalist docker/init_docker_rails_app.sh /code/init_docker_rails_app.sh
COPY --chown=inaturalist:inaturalist config/config.docker.yml /code/config/config.yml
COPY --chown=inaturalist:inaturalist config/database.docker.yml /code/config/database.yml
COPY --chown=inaturalist:inaturalist config/s3.docker.yml /code/config/s3.yml
COPY --chown=inaturalist:inaturalist config/secrets.docker.yml /code/config/secrets.yml
COPY --chown=inaturalist:inaturalist config/smtp.docker.yml /code/config/smtp.yml

RUN npm run webpack

RUN mkdir /code/public/assets
RUN mkdir /code/public/attachments
RUN chown inaturalist:inaturalist /code/public/assets
RUN chown inaturalist:inaturalist /code/public/attachments

ARG GIT_BRANCH
ARG GIT_COMMIT
ARG IMAGE_TAG
ARG BUILD_DATE

ENV GIT_BRANCH=${GIT_BRANCH}
ENV GIT_COMMIT=${GIT_COMMIT}
ENV IMAGE_TAG=${IMAGE_TAG}
ENV BUILD_DATE=${BUILD_DATE}

RUN echo "GIT_BRANCH=${GIT_BRANCH}" > /code/build_info
RUN echo "GIT_COMMIT=${GIT_COMMIT}" >> /code/build_info
RUN echo "IMAGE_TAG=${IMAGE_TAG}" >> /code/build_info
RUN echo "BUILD_DATE=${BUILD_DATE}" >> /code/build_info

EXPOSE 3000

CMD ["rails", "server", "-b", "0.0.0.0"]
