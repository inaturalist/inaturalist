# Contributing Code to iNaturalist

iNaturalist is open source for the sake of transparency, to take advantage of stuff that's free for open source projects, and so volunteer developers can help us out with small coding tasks if they'd like to. Unlike many open source projects, we do not intend it as a tool one can fork and customize for different applications. Instead, we code with only one instance in mind: iNaturalist.org. We mention this mainly to set expectations. We can't / won't stop you from forking this repo to make a celebrity spotting platform, but don't expect us to merge any of that code into this repo.

This guide is for people who want to help us out by writing code. If, on the other hand, you want to request features, report bugs you've found while using this software, or discuss anything else about iNaturalist, please start by posting in the [Forum](https://forum.inaturalist.org/). We mostly use Github for managing implementation, not for discussing what to implement or why we might want to implement it.

We will probably close pull requests that don't address open issues. Again, if you want to change functionality, the discussion should start in the [Forum](https://forum.inaturalist.org/), and if staff agree something should change, we'll make an issue, label it, and then you can work on it.

## Getting a Development Environment Set Up

The [Development Setup Guide](https://github.com/inaturalist/inaturalist/wiki/Development-Setup-Guide) should provide steps for getting set up, but be warned, it's not particularly easy. If you need help, please ask in the [Forum](https://forum.inaturalist.org).

## Reporting Issues

If you've found a problem in the code, please supply detailed reproduction conditions, cite line numbers, include exceptions / stack traces, etc. If you can't supply this kind of information, we will probably close your issue and suggest you post to the [Forum](https://forum.inaturalist.org/).

## Finding Issues to Work On

* Check out some of the [issues labeled "easy"](https://github.com/inaturalist/inaturalist/issues?q=is%3Aopen+is%3Aissue+label%3Aeasy)
* Avoid issues without labels. That generally means a member of iNat staff hasn't reviewed it and we may not be interested in the proposed change, or the issue hasn't been specified to the point where it can be implemented

## Working on an Issue

1. Leave a comment on the issue saying you're working on it
1. Fork the repo, and make an issue-specific branch in your fork that starts with the issue number followed by some descriptive, hyphen-separated text. For example, if the issue is number 1234 with a title like "Flagging a message blocks recipient from viewing it again," you should make a branch like `1234-message-flagging`
1. Work on your changes
1. When you're done, issue a pull request to the master branch in the main repo. iNat staff will review it when we have time

# Conduct and Behavior

We expect all contributors to abide by the [iNaturalist Community Guidelines](https://www.inaturalist.org/pages/community+guidelines), or at least the parts that aren't specific to the use of iNaturailst itself.
