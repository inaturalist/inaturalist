# angular-capitalize

[![Build Status](https://travis-ci.org/egilkh/angular-capitalize.svg)](https://travis-ci.org/egilkh/angular-capitalize)
[![Dependency Status](https://david-dm.org/egilkh/angular-capitalize.svg)](https://david-dm.org/egilkh/angular-capitalize)
[![devDependency Status](https://david-dm.org/egilkh/angular-capitalize/dev-status.svg)](https://david-dm.org/egilkh/angular-capitalize#info=devDependencies)

AngularJS filter for capitalization of sentences or words.

## Install

Use `bower` to install it:

`bower install angular-capitalize`

## Usage

Add a dependency on `ehFilters` to your Angular module:

`angular.module('awesome', ['ehFilters']);`

Include the module, e.g.:

`<script src="angular-capitalize.js"></script>`

### Locale

Include locale file if you need:

`<script src="angular-capitalize-locale_pt-br.js"></script>`

Filter things:

`{{ 'Some string' | capitalize }}` or `{{ 'random string' | capitalize:'firstChar' }}` or any other method.

## Formats

### first

Uppercases the first char of the string. Does not change the rest.

### all

Uppercases first char for each word in the string.

### firstChar

Uppcases the first char of the string, lowercases the rest.

### none

Lowercases the whole string.

### title

Uses John Gruber and John Resig method of capitalizing a title.
