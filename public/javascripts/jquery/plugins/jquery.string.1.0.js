/**
 * jquery.string - Prototype string functions for jQuery
 * (c) 2008 David E. Still (http://stilldesigning.com)
 * Original Prototype extensions (c) 2005-2008 Sam Stephenson (http://prototypejs.org)
 */

jQuery.extend({
	__stringPrototype: {
		/**
		 * ScriptFragmet, specialChar, and JSONFilter borrowed from Prototype 1.6.0.2
		 */
	 	JSONFilter: /^\/\*-secure-([\s\S]*)\*\/\s*$/,
		ScriptFragment: '<script[^>]*>([\\S\\s]*?)<\/script>',
		specialChar: {
			'\b': '\\b',
			'\t': '\\t',
			'\n': '\\n',
			'\f': '\\f',
			'\r': '\\r',
			'\\': '\\\\'
		},
	
		/**
		 * Check if the string is blank (white-space only or empty).
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		blank: function(s) {
			return /^\s*$/.test(this.s(s) || ' ');
		},
		/**
		 * Converts a string separated by dashes into a camelCase equivalent.
		 * For instance, 'foo-bar' would be converted to 'fooBar'.
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		camelize: function(s) {
			var a = this.s(s).split('-'), i;
			s = [a[0]];
			for (i=1; i<a.length; i++){
				s.push(a[i].charAt(0).toUpperCase() + a[i].substring(1));
			}
			s = s.join('');
			return this.r(arguments,0,s);
		},
		/**
		 * Capitalizes the first letter of a string and downcases all the others.
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		capitalize: function(s) {
			s = this.s(s);
			s = s.charAt(0).toUpperCase() + s.substring(1).toLowerCase();
			return this.r(arguments,0,s);
		},
		/**
		 * Replaces every instance of the underscore character ("_") by a dash ("-").
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		dasherize: function(s) {
			s = this.s(s).split('_').join('-');
			return this.r(arguments,0,s);
		},
		/**
		 * Check if the string is empty.
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		empty: function(s) {
			return this.s(s) === '';
		},
		/**
		 * Tests whether the end of a string matches pattern.
		 * @param {Object} pattern
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		endsWith: function(pattern, s) {
			s = this.s(s);
			var d = s.length - pattern.length;
			return d >= 0 && s.lastIndexOf(pattern) === d;
		},
		/**
		 * escapeHTML from Prototype-1.6.0.2 -- If it's good enough for Webkit and IE, it's good enough for Gecko!
		 * Converts HTML special characters to their entity equivalents.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		escapeHTML: function(s) {
			s = this.s(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
			return this.r(arguments,0,s);
		},
		/**
		 * evalJSON from Prototype-1.6.0.2
		 * Evaluates the JSON in the string and returns the resulting object. If the optional sanitize parameter
		 * is set to true, the string is checked for possible malicious attempts and eval is not called if one
		 * is detected.
		 * @param {String} s string to be evaluated
		 * @return {Object} evaluated JSON result
		 */
		evalJSON: function(sanitize, s) {
			s = this.s(s);
			var json = this.unfilterJSON(false, s);
			try {
				if (!sanitize || this.isJSON(json)) { return eval('(' + json + ')'); }
			} catch (e) { }
			throw new SyntaxError('Badly formed JSON string: ' + s);
		},
		/**
		 * evalScripts from Prototype-1.6.0.2
		 * Evaluates the content of any script block present in the string. Returns an array containing
		 * the value returned by each script.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		evalScripts: function(s) {
			var scriptTags = this.extractScripts(this.s(s)), results = [];
			if (scriptTags.length > 0) {
				for (var i = 0; i < scriptTags.length; i++) {
					results.push(eval(scriptTags[i]));
				}
			}
			return results;
		},
		/**
		 * extractScripts from Prototype-1.6.0.2
		 * Extracts the content of any script block present in the string and returns them as an array of strings.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		extractScripts: function(s) {
			var matchAll = new RegExp(this.ScriptFragment, 'img'), matchOne = new RegExp(this.ScriptFragment, 'im'), scriptMatches = this.s(s).match(matchAll) || [], scriptTags = [];
			if (scriptMatches.length > 0) {
				for (var i = 0; i < scriptMatches.length; i++) {
					scriptTags.push(scriptMatches[i].match(matchOne)[1] || '');
				}
			}
			return scriptTags;
		},
		/**
		 * Returns a string with all occurances of pattern replaced by either a regular string
		 * or the returned value of a function.  Calls sub internally.
		 * @param {Object} pattern RegEx pattern or string to replace
		 * @param {Object} replacement string or function to replace matched patterns
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 * @see sub
		 */
		gsub: function(pattern, replacement, s) {
			s = this.s(s);
			if (jQuery.isFunction(replacement)) { s = this.sub(pattern, replacement, -1, s); }
			/* if replacement is not a function, do this the easy way; it's quicker */
			else { s = s.split(pattern).join(replacement); }
			return this.r(arguments,2,s);
		},
		/**
		 * Check if the string contains a substring.
		 * @param {Object} pattern RegEx pattern or string to find
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean result
		 */
		include: function(pattern, s) {
			return this.s(s).indexOf(pattern) > -1;
		},
		/**
		 * Returns a debug-oriented version of the string (i.e. wrapped in single or double quotes,
		 * with backslashes and quotes escaped).
		 * @param {Object} useDoubleQuotes escape double-quotes instead of single-quotes
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		inspect: function(useDoubleQuotes, s) {
			s = this.s(s);
			var escapedString;
			try {
				escapedString = this.sub(/[\x00-\x1f\\]/, function(match) {
					var character = jQuery.__stringPrototype.specialChar[match[0]];
					return character ? character : '\\u00' + match[0].charCodeAt().toPaddedString(2, 16);
			    }, -1, s);
			} catch(e) { escapedString = s; }
			s = (useDoubleQuotes) ? '"' + escapedString.replace(/"/g, '\\"') + '"' : "'" + escapedString.replace(/'/g, '\\\'') + "'";
			return this.r(arguments,1,s);
		},
		/**
		 * Treats the string as a Prototype-style Template and fills it with object’s properties.
		 * @param {Object} obj object of values to replace in string
		 * @param {Object} pattern RegEx pattern for template replacement (default matches Ruby-style '#{attribute}')
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		interpolate: function(obj, pattern, s) {
			s = this.s(s);
			if (!pattern) { pattern = /(\#\{\s*(\w+)\s*\})/; }
			var gpattern = new RegExp(pattern.source, "g");
			var matches = s.match(gpattern), i;
			for (i=0; i<matches.length; i++) {
				s = s.replace(matches[i], obj[matches[i].match(pattern)[2]]);
			}
			return this.r(arguments,2,s);
		},
		/**
		 * isJSON from Prototype-1.6.0.2
		 * Check if the string is valid JSON by the use of regular expressions. This security method is called internally.
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean result
		 */
		isJSON: function(s) {
			s = this.s(s);
			if (this.blank(s)) { return false; }
			s = s.replace(/\\./g, '@').replace(/"[^"\\\n\r]*"/g, '');
			return (/^[,:{}\[\]0-9.\-+Eaeflnr-u \n\r\t]*$/).test(s);
		},
		/**
		 * Evaluates replacement for each match of pattern in string and returns the original string.
		 * Calls sub internally.
		 * @param {Object} pattern RegEx pattern or string to replace
		 * @param {Object} replacement string or function to replace matched patterns
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 * @see sub
		 */
		scan: function(pattern, replacement, s) {
			s = this.s(s);
			this.sub(pattern, replacement, -1, s);
			return this.r(arguments,2,s);
		},
		/**
		 * Tests whether the beginning of a string matches pattern.
		 * @param {Object} pattern
		 * @param {String} s string to be evaluated
		 * @return {Boolean} boolean of result
		 */
		startsWith: function(pattern, s) {
			return this.s(s).indexOf(pattern) === 0;
		},
		/**
		 * Trims white space from the beginning and end of a string.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		strip: function(s) {
			s = jQuery.trim(this.s(s));
			return this.r(arguments,0,s);
		},
		/**
		 * Strips a string of anything that looks like an HTML script block.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		stripScripts: function(s) {
			s = this.s(s).replace(new RegExp(this.ScriptFragment, 'img'), '');
			return this.r(arguments,0,s);
		},
		/**
		 * Strips a string of any HTML tags.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		stripTags: function(s) {
			s = this.s(s).replace(/<\/?[^>]+>/gi, '');
			return this.r(arguments,0,s);
		},
		/**
		 * Returns a string with the first count occurances of pattern replaced by either a regular string
		 * or the returned value of a function.
		 * @param {Object} pattern RegEx pattern or string to replace
		 * @param {Object} replacement string or function to replace matched patterns
		 * @param {Integer} count number of (default = 1, -1 replaces all)
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		sub: function(pattern, replacement, count, s) {
			s = this.s(s);
			if (pattern.source && !pattern.global) {
				var patternMods = (pattern.ignoreCase)?"ig":"g";
				patternMods += (pattern.multiline)?"m":"";
				pattern = new RegExp(pattern.source, patternMods);
			}
			var sarray = s.split(pattern), matches = s.match(pattern);
			if (jQuery.browser.msie) {
				if (s.indexOf(matches[0]) == 0) sarray.unshift("");
				if (s.lastIndexOf(matches[matches.length-1]) == s.length - matches[matches.length-1].length) sarray.push("");
			}
			count = (count < 0)?(sarray.length-1):count || 1;
			s = sarray[0];
			for (var i=1; i<sarray.length; i++) {
				if (i <= count) {
					if (jQuery.isFunction(replacement)) {
						s += replacement(matches[i-1] || matches) + sarray[i];
					} else { s += replacement + sarray[i]; }
				} else { s += (matches[i-1] || matches) + sarray[i]; }
			}
			return this.r(arguments,3,s);
		},
		/**
		 * 
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		succ: function(s) {
			s = this.s(s);
			s = s.slice(0, s.length - 1) + String.fromCharCode(s.charCodeAt(s.length - 1) + 1);
			return this.r(arguments,0,s);
		},
		/**
		 * Concatenate count number of copies of s together and return result.
		 * @param {Integer} count Number of times to repeat s
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		times: function(count, s) {
			s = this.s(s);
			var newS = "";
			for (var i=0; i<count; i++) {
				newS += s;
			}
			return this.r(arguments,1,newS);
		},
		/**
		 * Returns a JSON string
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		toJSON: function(s) {
			return this.r(arguments,0,this.inspect(true, this.s(s)));
		},
		/**
		 * Parses a URI-like query string and returns an object composed of parameter/value pairs.
		 * This method is mainly targeted at parsing query strings (hence the default value of '&'
		 * for the seperator argument). For this reason, it does not consider anything that is either
		 * before a question mark (which signals the beginning of a query string) or beyond the hash 
		 * symbol ("#"), and runs decodeURIComponent() on each parameter/value pair.
		 * @param {Object} separator string to separate parameters (default = '&')
		 * @param {Object} s
		 * @return {Object} object
		 */
		toQueryParams: function(separator, s) {
			s = this.s(s);
			var paramsList = s.substring(s.indexOf('?')+1).split('#')[0].split(separator || '&'), params = {}, i, key, value, pair;
			for (i=0; i<paramsList.length; i++) {
				pair = paramsList[i].split('=');
				key = decodeURIComponent(pair[0]);
				value = (pair[1])?decodeURIComponent(pair[1]):undefined;
				if (params[key]) {
					if (typeof params[key] == "string") { params[key] = [params[key]]; }
					params[key].push(value);
				} else { params[key] = value; }
			}
			return params;
		},
		/**
		 * truncate from Prototype-1.6.0.2
		 * Truncates a string to the given length and appends a suffix to it (indicating that it is only an excerpt).
		 * @param {Object} length length of string to truncate to
		 * @param {Object} truncation string to concatenate onto truncated string (default = '...')
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		truncate: function(length, truncation, s) {
			s = this.s(s);
			length = length || 30;
			truncation = (!truncation) ? '...' : truncation;
			s = (s.length > length) ? s.slice(0, length - truncation.length) + truncation : String(s);
			return this.r(arguments,2,s);
		},
		/**
		 * Converts a camelized string into a series of words separated by an underscore ("_").
		 * e.g. $.string('borderBottomWidth').underscore().str = 'border_bottom_width'
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		underscore: function(s) {
			s = this.sub(/[A-Z]/, function(c) { return "_"+c.toLowerCase(); }, -1, this.s(s));
			if (s.charAt(0) == "_") s = s.substring(1);
			return this.r(arguments,0,s);
		},
		/**
		 * unescapeHTML from Prototype-1.6.0.2 -- If it's good enough for Webkit and IE, it's good enough for Gecko!
		 * Strips tags and converts the entity forms of special HTML characters to their normal form.
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		unescapeHTML: function(s) {
			s = this.stripTags(this.s(s)).replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>');
			return this.r(arguments,0,s);
		},
		/**
		 * unfilterJSON from Prototype-1.6.0.2.
		 * @param {Function} filter
		 * @param {String} s string to be evaluated
		 * @return {Object} .string object (or string if internal)
		 */
		unfilterJSON: function(filter, s) {
			s = this.s(s);
			filter = filter || this.JSONFilter;
			var filtered = s.match(filter);
			s = (filtered !== null)?filtered[1]:s;
			return this.r(arguments,1,jQuery.trim(s));
		},
	
		/**
		 * Sets .str property and returns $.string object.
		 * @param {String} s string to be evaluated
		 */
		r: function(args, size, s) {
			if (args.length > size || this.str === undefined) {
				return s;
			} else {
				this.str = ''+s;
				return this;
			};
		},
		s: function(s) {
			if (s === '' || s) { return s; }
			if (this.str === '' || this.str) { return this.str; }
			return this;
		}
	},
	string: function(str) {
		if (str === String.prototype) { jQuery.extend(String.prototype, jQuery.__stringPrototype); }
		else { return jQuery.extend({ str: str }, jQuery.__stringPrototype); }
	}
});
jQuery.__stringPrototype.parseQuery = jQuery.__stringPrototype.toQueryParams;
