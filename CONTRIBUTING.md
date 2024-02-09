# Contributing Code to iNaturalist

iNaturalist is open source for the sake of transparency, to take advantage of stuff that's free for open source projects, and so volunteer developers can help us out with small coding tasks if they'd like to. Unlike many open source projects, we do not intend it as a tool one can fork and customize for different applications. Instead, we code with only one instance in mind: iNaturalist.org. We mention this mainly to set expectations. We can't / won't stop you from forking this repo to make a celebrity spotting platform, but don't expect us to merge any of that code into this repo.

This guide is for people who want to help us out by writing code. If, on the other hand, you want to request features, report bugs you've found while using this software, or discuss anything else about iNaturalist, please start by posting in the [Forum](https://forum.inaturalist.org/). We mostly use Github for managing implementation, not for discussing what to implement or why we might want to implement it.

We will probably close pull requests that don't address open issues. Again, if you want to change functionality, the discussion should start in the [Forum](https://forum.inaturalist.org/), and if staff agree something should change, we'll make an issue, label it, and then you can work on it.

## Getting a Development Environment Set Up

### Using Docker

The development environment for iNaturalist is set up to run containerized services in Docker. Furthermore this configuration allows running the [API](https://github.com/inaturalist/iNaturalistAPI) alongside the services. 

1. Install [Docker](https://www.docker.com/)
1. Copy `docker-compose.override.yml.example` to `docker-compose.override.yml` and customize credentials
1. Run `make services` to start Elasticsearch, memcached, redis, and PostgeSQL. Run `make services-api` to include the API and run in the foreground (see note above; you'll also need to add working versions of `docker-compose.override.yml` and `config.js` to that directory to get the API to run).

   **Note**: If iNaturalistAPI is not in a sibling directory to this repository specify the path as such: `make services-api API_PATH=path/to/api`.

1. Run `ruby bin/setup` to set up gems, config files, and database
1. Start the server: `rails server -b 127.0.0.1`

Additionally, the [Development Setup Guide](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide) covers [React and Node](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide#react--node-modules), [seed data](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide#load-some-seed-data), and [additional tools](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide#create-test-users-places-and-observations) to help you get going.
You can skip the sections on setting up redis, memcached, postgis, and Elasticsearch when running these in Docker.

#### Running tests

1. Run `make services` to start the required services
2. Make sure the test database is setup if this is the first time running tests: `bundle exec rake db:setup RAILS_ENV=test`
3. Run specs: `bundle exec rspec` or `bundle exec rspec file/to/test.rb`

### Running services locally

The [Development Setup Guide](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide) should provide steps for getting set up, but be warned, it's not particularly easy. If you need help, please ask in the [Forum](https://forum.inaturalist.org).

## Reporting Issues

If you've found a problem in the code, please supply detailed reproduction conditions, cite line numbers, include exceptions / stack traces, etc. If you can't supply this kind of information, we will probably close your issue and suggest you post to the [Forum](https://forum.inaturalist.org/).

## Finding Issues to Work On

* Choose an issue from our [Web Project](https://github.com/orgs/inaturalist/projects/3), where we've prioritized some of our many issues. It also includes issues for our [API](https://github.com/inaturalist/iNaturalistAPI)
* You can also peruse our all of our [issues](https://github.com/inaturalist/inaturalist/issues)
* Avoid issues without labels. That generally means a member of iNat staff hasn't reviewed it and we may not be interested in the proposed change, or the issue hasn't been specified to the point where it can be implemented

## Working on an Issue

1. Leave a comment on the issue saying you're working on it. iNat staff will try to assign you when we know you're working on it. If we don't see a PR from you in a few weeks, we will probably unassign you
1. Fork the repo, and make an issue-specific branch in your fork that starts with the issue number followed by some descriptive, hyphen-separated text. For example, if the issue is number 1234 with a title like "Flagging a message blocks recipient from viewing it again," you should make a branch like `1234-message-flagging`
1. Work on your changes
1. When you're done, issue a pull request to the main branch in the [inaturalist repo](https://github.com/inaturalist/inaturalist). iNat staff will review it when we have time

# Reporting Security Issues

You should report security issues that require confidential communication to [help+security@inaturalist.org](mailto:help+security@inaturalist.org). We do not offer any rewards or bounties for reporting security issues, though we may offer to list your name and URL here if we act on your report. Our heartfelt thanks to everyone who has reported issues, including (but not limited to):

* [Sohail Ahmed](https://www.linkedin.com/in/sohail-ahmed-755776184/)
* [Abdul Wahab](https://twitter.com/BugHunt25657683)

# Conduct and Behavior

We expect all contributors to abide by the [iNaturalist Community Guidelines](https://www.inaturalist.org/pages/community+guidelines), or at least the parts that aren't specific to the use of iNaturailst itself.
