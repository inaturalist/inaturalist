# Changelog

## 1.3.0 - 2018-09-04
- Update angular.js version in bower.json ([#306](https://github.com/urish/angular-moment/pull/306), contributed by [jniles](https://github.com/jniles))

## 1.2.0 - 2017-12-02
- Update moment.js version in bower.json ([#300](https://github.com/urish/angular-moment/pull/300), contributed by [jc1arke](https://github.com/jc1arke))

## 1.1.0 - 2017-09-28
- Add additional typeof check for the global.moment instance ([#295](https://github.com/urish/angular-moment/pull/295), contributed by [schester44](https://github.com/schester44))

## 1.0.1 - 2016-12-01
- Angular 1.6 support ([#278](https://github.com/urish/angular-moment/pull/278), contributed by [alippai](https://github.com/alippai))

## 1.0.0 - 2016-10-06
- Improvments to the UMD code

Breaking change: The AMD version now exports the module name ('angularMoment') instead of the actual module object. 

## 1.0.0-beta.6 - 2016-04-24
- Support for setting the units of the full date threshold of `am-time-ago` ([#237](https://github.com/urish/angular-moment/pull/237), contributed by [denistrustepain](https://github.com/denistrustepain))
- Add optional arguments `referenceTime` and `formats` to the `amCalendar` filter ([#241](https://github.com/urish/angular-moment/pull/241), contributed by [Nitro-N](https://github.com/Nitro-N))
- Support moment 2.13.x and above

## 1.0.0-beta.5 - 2016-03-18
- Bugfix: `amTimeAgo` shouldn't convert the time to local timezone on the element's `title` attribute ([#226](https://github.com/urish/angular-moment/pull/226), contributed by [stackia](https://github.com/stackia))
- Support moment 2.12.x

## 1.0.0-beta.4 - 2016-02-09
- Add amStartOf and amEndOf filter ([#203](https://github.com/urish/angular-moment/pull/203), contributed by [pratik14](https://github.com/pratik14))
- Support Moment 2.11.x
- Happy Year of the Monkey!

## 1.0.0-beta.3 - 2015-11-10

- Support AngularJS 1.5.x 
- Support for nw.js ([#196](https://github.com/urish/angular-moment/pull/196), contributed by [makkesk8](https://github.com/makkesk8))
- Bugfix: `title` attribute does update when model changes ([#201](https://github.com/urish/angular-moment/pull/201), contributed by [stackia](https://github.com/stackia))

## 1.0.0-beta.2 - 2015-09-20

- Bugfix: Infinite digest loop when combining `am-time-ago` and `amTimezone` ([#178](https://github.com/urish/angular-moment/issues/178))
- Bugfix: Cannot use angular-moment under webpack ([#108](https://github.com/urish/angular-moment/issues/108))
- Add `amLocal` filter (see [#114](https://github.com/urish/angular-moment/issues/114))

## 1.0.0-beta.1 - 2015-09-14

!!! BREAKING CHANGE !!!

Preprocessors, timezones and input format were removed from am-time-ago and all filters. Use the new `amFromUnix`, 
`amUtc`, `amUtcOffset`, `amTimezone`, and `amParse` filters instead. 

Examples:
* `<time am-time-ago="myDate" am-format="YYYY-MM-DD">` becomes `<time am-time-ago="myDate|amParse:'YYYY-MM-DD'">`
* `<time am-time-ago="myDate" am-preprocess="unix">` becomes `<time am-time-ago="myDate|amFromUnix">`
* `{{myDate|amCalendar:'unix'}}` becomes `{{myDate|amFromUnix|amCalendar}}`
* `{{myDate|amCalendar:null:'PDT'}}` becomes `{{myDate|amTimezone:'PDT'|amCalendar}}`

The removal of the preprocessors also affects the other positional parameters of the `amTimeAgo`:
 
`{{myDate|amTimeAgo:null:true:fromDate}}` becomes `{{myDate|amTimeAgo:true:fromDate}}`.

For more information, please see [#174](https://github.com/urish/angular-moment/issues/174).

## 0.10.3 - 2015-09-05
- Allow `amDateFormat` to work with custom formatted input date strings ([#162](https://github.com/urish/angular-moment/pull/162), contributed by [jblashka](https://github.com/jblashka))
- `amAdd`, `amSubtract` - add/subtract a value from a given date ([#171](https://github.com/urish/angular-moment/pull/171), contributed by [nicholasruggeri](https://github.com/nicholasruggeri))
- Bugfix: Timezones with a 'Z' somewhere in them all become UTC ([#168](https://github.com/urish/angular-moment/issues/168)).

## 0.10.2 - 2015-07-28
- Look for `moment` on the `global` object ([#133](https://github.com/urish/angular-moment/pull/133), contributed by [kitbrennan90](https://github.com/kitbrennan90))
- Add support to use UTC offset timezones in addition to named timezones ([#151](https://github.com/urish/angular-moment/pull/151), contributed by [DiegoZoracKy](https://github.com/DiegoZoracKy))
- Add timezone parameter for amCalendar filter ([#152](https://github.com/urish/angular-moment/pull/152), contributed by [DiegoZoracKy](https://github.com/DiegoZoracKy))
- Add `am-from` parameter to the `amTimeAgo` directive ([#145](https://github.com/urish/angular-moment/pull/145), contributed by [baleato](https://github.com/baleato))
- Add `from` parameter to the `amTimeAgo` filter ([#146](https://github.com/urish/angular-moment/pull/146), contributed by [pipo02mix](https://github.com/pipo02mix))

## 0.10.1 - 2015-05-01
- Fix broken SystemJS/JSPM support (see [#104](https://github.com/urish/angular-moment/issues/104))

## 0.10.0 - 2015-04-10
- Breaking change: removed one-time binding for `am-time-ago` in favor of AngularJS 1.3's one time binding ([#122](https://github.com/urish/angular-moment/issues/122))
- Remove support for AngularJS 1.0.x and 1.1.x.
- Support moment.js v2.10.x
- Support for displaying full dates in `am-time-ago` (see [#75](https://github.com/urish/angular-moment/issues/75)) 
- Support Angular Core's style CommonJS standard ([#123](https://github.com/urish/angular-moment/pull/123), contributed by [seanhealy](https://github.com/seanhealy))
- Added an optional timezone parameter to amDateFormat ([#90](https://github.com/urish/angular-moment/pull/90), contributed by [robertbrooker](https://github.com/robertbrooker))

## 0.9.2 - 2015-03-17
- Critical fix: npm install angular-moment fails ([#121](https://github.com/urish/angular-moment/issues/121))

## 0.9.1 - 2015-03-17
- Add support for locale strings customization ([#102](https://github.com/urish/angular-moment/pull/102), contributed by [vosi](https://github.com/vosi))
- Add `amDifference` filter ([#120](https://github.com/urish/angular-moment/pull/120), contributed by [ajhodges](https://github.com/ajhodges))
- Support for changing the timezone via `amMoment.changeTimezone()` ([#92](https://github.com/urish/angular-moment/issues/92))
- Support for AngularJS 1.4.x
- Remove explicit module name for RequireJS ([#112](https://github.com/urish/angular-moment/pull/112), contributed by [WilliamCarter](https://github.com/WilliamCarter))

## 0.9.0 - 2015-01-11
- Support moment.js v2.9.0. See [here](https://gist.github.com/ichernev/0c9a9b49951111a27ce7) for changelog.
- Removed support for older moment.js versions. Only 2.8.0 and newer versions are now supported.
- Removed deprecated method: `amMoment.changeLanguage()`. Use `amMoment.changeLocale()` instead.
- Removed deprecated event: `amMoment:languageChange`. Listen for `amMoment:localeChange` instead.
- Filters are now stateful by default (fixes [#97](https://github.com/urish/angular-moment/issues/97)).
- The project is now available on [NuGet](https://www.nuget.org/packages/angular-moment/) ([#99](https://github.com/urish/angular-moment/pull/99), contributed by [markvp](https://github.com/markvp)).

## 0.8.3 - 2014-12-08
- `amTimeAgo` filter ([#96](https://github.com/urish/angular-moment/pull/96), contributed by [maxklenk](https://github.com/maxklenk))
- Show formatted time as element title ([#78](https://github.com/urish/angular-moment/pull/78), contributed by [ctesene](https://github.com/ctesene))
- Support commonjs and browserify ([#95](https://github.com/urish/angular-moment/pull/95), contributed by [Pencroff](https://github.com/Pencroff))
- SystemJS Loader support ([#85](https://github.com/urish/angular-moment/pull/85), contributed by [capaj](https://github.com/capaj))

## 0.8.2 - 2014-09-07
- `amMoment.changeLanguage()` was deprecated in favor of `amMoment.changeLocale()` (following [a change](http://momentjs.com/docs/#/i18n/changing-locale/) introduced in moment v2.8.1)
- Bugfix: changing the locale emitted a deprecation warning (see [#76](https://github.com/urish/angular-moment/issues/76) for details).

## 0.8.1 - 2014-09-01
- Support moment.js v2.8.0. See [here](https://gist.github.com/ichernev/ac3899324a5fa6c8c9b4) for changelog.
- Support moment-timezone v0.2.1. See [here](https://github.com/moment/moment-timezone/blob/develop/changelog.md#021-2014-08-02) for changelog.
- Bugfix: `updateTime()` is called too often for future dates ([#73](https://github.com/urish/angular-moment/issues/73)) 

## 0.8.0 - 2014-07-26
- Generate source map for the minified version ([#50](https://github.com/urish/angular-moment/issues/50))
- Add support HTML `<time>` element - set the `datetime` attribute ([#41](https://github.com/urish/angular-moment/pull/41), contributed by [gsklee](https://github.com/gsklee))
- Add default format (angularMomentConfig.format config property) ([#52](https://github.com/urish/angular-moment/pull/52), contributed by [otang](https://github.com/otang))
- Add `serverTime` configuration option ([#53](https://github.com/urish/angular-moment/pull/53), contributed by [Facundo Pedrazzini](https://github.com/Facuu7))
- Implement one-time binding for `am-time-ago` ([#54](https://github.com/urish/angular-moment/pull/54), contributed by [Ephi Gabay](https://github.com/ephigabay))
- Support moment.js v2.7.0. See [here](https://gist.github.com/ichernev/b0a3d456d5a84c9901d7) for changelog.
- Support moment-timezone v0.1.0. See [here](https://github.com/moment/moment-timezone/blob/develop/changelog.md#010-2014-06-23) for changelog.

## 0.7.1 - 2014-05-16
- bugfix: Preprocess set in configuration not used by filters ([#49](https://github.com/urish/angular-moment/issues/49))

## 0.7.0 - 2014-04-19
- Use `moment` as an injectable constant instead of relying on `$window.moment` ([#35](https://github.com/urish/angular-moment/pull/35), contributed by [just-boris](https://github.com/just-boris))
- Require.js support ([#36](https://github.com/urish/angular-moment/issues/36))
- Add am-preprocess attribute to support unix and utc timestamps ([#38](https://github.com/urish/angular-moment/pull/38), contributed by [jspaper](https://github.com/jspaper))
- NGDoc documentation ([#40](https://github.com/urish/angular-moment/issues/40))
- Enable support for AngularJS 1.3.x in bower.json
- Support moment.js v2.6.0. See [here](https://gist.github.com/ichernev/10544682) for changelog.

## 0.6.2 - 2014-02-05
- Add `amMoment` service with a `changeLanguage()` method ([#32](https://github.com/urish/angular-moment/pull/32), contributed by [Ornthalas](https://github.com/Ornthalas))
- bower.json: Move `moment-timezone` to devDependencies (fixes [#34](https://github.com/urish/angular-moment/issues/34))

## 0.6.1 - 2014-01-31
- Add optional timezone support to `amCalendar` and `amDateFormat` filters ([#27](https://github.com/urish/angular-moment/pull/27), contributed by [kayhadrin](https://github.com/kayhadrin))
- Happy Year of the Horse!

## 0.6.0 - 2013-12-24

- Add optional `am-without-suffix` attribute to `am-time-ago` ([#22](https://github.com/urish/angular-moment/issues/22), contributed by [hramaker](https://github.com/hramaker))
- Support moment.js v2.5.0. See [here](https://gist.github.com/ichernev/8104451) for changelog.
- Merry Christmas!

## 0.5.2 - 2013-11-17

- Add `amCalendar` filter ([#24](https://github.com/urish/angular-moment/issues/24), contributed by [OndraM](https://github.com/OndraM))

## 0.5.1 - 2013-11-09

- Add `amDuration` filter ([#20](https://github.com/urish/angular-moment/issues/20), contributed by [gabrielstuff](https://github.com/gabrielstuff))

## 0.5.0 - 2013-11-02

- Use $window.setTimeout instead of $timeout, fixes protractor synchronization issue ([#19](https://github.com/urish/angular-moment/issues/19))

## 0.4.2 - 2013-10-30

- Add settings constant for configuring moment.js withoutSuffix-option ([#18](https://github.com/urish/angular-moment/pull/18))

## 0.4.1 - 2013-10-27

- Support moment.js v2.4.0. See [here](https://github.com/moment/moment/#240) for changelog.

## 0.4.0 - 2013-10-08

- Support moment.js v2.3.0. See [here](https://gist.github.com/ichernev/6864354) for possibly breaking changes.

## 0.3.0 - 2013-10-07

- Bugfix: `am-time-ago` support for empty string ([#15](https://github.com/urish/angular-moment/issues/15))
- Behavior change: `am-time-ago` will only change the text once there is date

## 0.2.2 - 2013-09-29

- Add support for passing unix timestamp as a string to `amDateFormat` filter ([#14](https://github.com/urish/angular-moment/issues/14))

## 0.2.1 - 2013-09-13

- Fix an issue with tests failing on a different timezone
- Support moment 2.2.x, AngularJS 1.2

## 0.2.0 - 2013-08-22

- Add optional `am-format` attribute to `am-time-ago` ([#11](https://github.com/urish/angular-moment/issues/11))
- Add new `amDateFormat` filter ([#12](https://github.com/urish/angular-moment/issues/12))
- Add changelog file

## 0.1.1 - 2013-06-08

- Fix to support iOS ([#2](https://github.com/urish/angular-moment/pull/2), contributed by [giuseppeaiello](https://github.com/giuseppeaiello))

## 0.1.0 - 2013-05-27

- Initial release
