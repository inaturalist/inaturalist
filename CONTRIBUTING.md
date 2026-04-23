# Contributing to iNaturalist

## About this codebase

iNaturalist's code is open source primarily for **transparency** — we want our community to be able to see how the platform works. Unlike many open source projects, we don't maintain this codebase as a general-purpose tool for forking or customization. We build it with one deployment in mind: iNaturalist.org and the iNaturalist mobile apps.

We will probably close pull requests that don't address open issues. Again, if you want to change functionality, the discussion should start in the [Forum](https://forum.inaturalist.org/), and if staff agree something should change, we'll make an issue, label it, and then you can work on it.

We're a small team. Our capacity to review and integrate external contributions is limited, and we can't commit to responding to every inquiry or pull request.

---

## Bugs and feature requests

**Please don't open GitHub issues for user-facing bug reports or feature requests.**

We track our work internally and triage inbound requests through the [iNaturalist Forum](https://forum.inaturalist.org). Filing a GitHub issue is unlikely to result in action, and you're much more likely to get a response — and to hear from other community members with similar experiences — on the Forum.

- **Bug reports:** [forum.inaturalist.org](https://forum.inaturalist.org) → Bug Reports category
- **Feature requests:** [forum.inaturalist.org](https://forum.inaturalist.org) → Feature Requests category

If you've found a problem in the code, please supply detailed reproduction conditions, cite line numbers, include exceptions / stack traces, etc. If you can't supply this kind of information, we will probably close your issue and suggest you post to the forum links above.

# Reporting Security Issues

You should report security issues that require confidential communication to [help+security@inaturalist.org](mailto:help+security@inaturalist.org). We do not offer any rewards or bounties for reporting security issues, though we may offer to list your name and URL here if we act on your report. Our heartfelt thanks to everyone who has reported issues, including (but not limited to):

* [Sohail Ahmed](https://www.linkedin.com/in/sohail-ahmed-755776184/)
* [Abdul Wahab](https://twitter.com/BugHunt25657683)

---

## Code contributions

We occasionally accept code contributions, but only when they closely align with work already on our roadmap. Before spending time writing code, we strongly recommend:

1. **Post on the Forum first.** Describe what you want to do and why. This gives us a chance to tell you whether it's something we'd ever merge, saving everyone time.
2. **Wait for a signal from staff.** If we think it's a fit, someone on the team will say so and can give guidance on approach.
3. **Keep scope small.** Small, focused pull requests are far more likely to be reviewed and merged than large ones.

We may close pull requests that arrive without prior discussion, or that don't align with our current priorities — not because we don't appreciate the effort, but because of our limited capacity to review and integrate external code.

### What makes a contribution likely to succeed

- It fixes a concrete, reproducible bug
- It's something we've indicated interest in on the Forum or in a GitHub issue
- It's a small, self-contained change with minimal side effects
- It includes tests where appropriate
- It follows the existing code style of the file(s) being changed

## Working on an Issue

1. Leave a comment on the issue saying you're working on it. iNat staff will try to assign you when we know you're working on it. If we don't see a PR from you in a few weeks, we will probably unassign you
2. Fork the repo, and make an issue-specific branch in your fork that starts with the issue number followed by some descriptive, hyphen-separated text. For example, if the issue is number 1234 with a title like "Flagging a message blocks recipient from viewing it again," you should make a branch like `1234-message-flagging`
3. Work on your changes
4. When you're done, issue a pull request to the main branch in the [inaturalist repo](https://github.com/inaturalist/inaturalist). iNat staff will review it when we have time

---

## Translations

Translations are handled separately through [Crowdin](https://crowdin.com/project/inaturalist), not through pull requests. If you'd like to help translate iNaturalist into another language, that's the place to start — and it's one of the most impactful ways to contribute to the project.

---

## Code of conduct

All contributors are expected to follow the [iNaturalist Community Guidelines](https://www.inaturalist.org/pages/community+guidelines), or at least the parts that aren't specific to using iNaturalist as a naturalist.

---

## Questions about the code

If you have a technical question about how something works — you're building an integration, you're curious about an architectural decision, or you've encountered something confusing — you can open a [GitHub Discussion](https://github.com/inaturalist/inaturalist/discussions). We can't promise a quick response, but discussions are more likely to get attention than issues, and they benefit others who have the same question.

---

## Getting a Development Environment Set Up

### Using Docker

The development environment for iNaturalist is set up to run containerized services in Docker. Furthermore this configuration allows running the [API](https://github.com/inaturalist/iNaturalistAPI) alongside the services. 

1. Install and launch [Docker](https://www.docker.com/). Make sure your current user has access to the docker daemon with `docker run hello-world`.
1. Copy `docker-compose.override.yml.example` to `docker-compose.override.yml` and customize credentials
1. Run `make services` to start Elasticsearch, memcached, redis, and PostgreSQL. Run `make services-api` to include the API and run in the foreground (see note above; you'll also need to add working versions of `docker-compose.override.yml` and `config.js` to that directory to get the API to run).

   **Note**: If iNaturalistAPI is not in a sibling directory to this repository, specify the path as such: `make services-api API_PATH=path/to/api`.

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

If you have trouble, post a question in the Q+A section of [Discussions](https://github.com/inaturalist/inaturalist/discussions/) in this repo.