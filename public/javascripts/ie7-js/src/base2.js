
// This is a cut-down version of base2 (http://code.google.com/p/base2/)

var _slice = Array.prototype.slice;

// private
var _FORMAT = /%([1-9])/g;
var _LTRIM = /^\s\s*/;
var _RTRIM = /\s\s*$/;
var _RESCAPE = /([\/()[\]{}|*+-.,^$?\\])/g;           // safe regular expressions
var _BASE = /\bbase\b/;
var _HIDDEN = ["constructor", "toString"];            // only override these when prototyping

var prototyping;

function Base(){};
Base.extend = function(_instance, _static) {
  // Build the prototype.
  prototyping = true;
  var _prototype = new this;
  extend(_prototype, _instance);
  prototyping = false;

  // Create the wrapper for the constructor function.
  var _constructor = _prototype.constructor;
  function klass() {
    // Don't call the constructor function when prototyping.
    if (!prototyping) _constructor.apply(this, arguments);
  };
  _prototype.constructor = klass;

  // Build the static interface.
  klass.extend = arguments.callee;
  extend(klass, _static);
  klass.prototype = _prototype;
  return klass;
};
Base.prototype.extend = function(source) {
  return extend(this, source);
};

// A collection of regular expressions and their associated replacement values.
// A Base class for creating parsers.

var _HASH   = "#";
var _KEYS   = "~";

var _RG_ESCAPE_CHARS    = /\\./g;
var _RG_ESCAPE_BRACKETS = /\(\?[:=!]|\[[^\]]+\]/g;
var _RG_BRACKETS        = /\(/g;

var RegGrp = Base.extend({
  constructor: function(values) {
    this[_KEYS] = [];
    this.merge(values);
  },

  exec: function(string) {
    var items = this, keys = this[_KEYS];    
    return String(string).replace(new RegExp(this, this.ignoreCase ? "gi" : "g"), function() {
      var item, offset = 1, i = 0;
      // Loop through the RegGrp items.
      while ((item = items[_HASH + keys[i++]])) {
        var next = offset + item.length + 1;
        if (arguments[offset]) { // do we have a result?
          var replacement = item.replacement;
          switch (typeof replacement) {
            case "function":
              return replacement.apply(items, _slice.call(arguments, offset, next));
            case "number":
              return arguments[offset + replacement];
            default:
              return replacement;
          }
        }
        offset = next;
      }
    });
  },

  add: function(expression, replacement) {
    if (expression instanceof RegExp) {
      expression = expression.source;
    }
    if (!this[_HASH + expression]) this[_KEYS].push(String(expression));
    this[_HASH + expression] = new RegGrp.Item(expression, replacement);
  },

  merge: function(values) {
    for (var i in values) this.add(i, values[i]);
  },

  toString: function() {
    // back references not supported in simple RegGrp
    return "(" + this[_KEYS].join(")|(") + ")";
  }
}, {
  IGNORE: "$0",

  Item: Base.extend({
    constructor: function(expression, replacement) {
      expression = expression instanceof RegExp ? expression.source : String(expression);

      if (typeof replacement == "number") replacement = String(replacement);
      else if (replacement == null) replacement = "";

      // does the pattern use sub-expressions?
      if (typeof replacement == "string" && /\$(\d+)/.test(replacement)) {
        // a simple lookup? (e.g. "$2")
        if (/^\$\d+$/.test(replacement)) {
          // store the index (used for fast retrieval of matched strings)
          replacement = parseInt(replacement.slice(1));
        } else { // a complicated lookup (e.g. "Hello $2 $1")
          // build a function to do the lookup
          var Q = /'/.test(replacement.replace(/\\./g, "")) ? '"' : "'";
          replacement = replacement.replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\$(\d+)/g, Q +
            "+(arguments[$1]||" + Q+Q + ")+" + Q);
          replacement = new Function("return " + Q + replacement.replace(/(['"])\1\+(.*)\+\1\1$/, "$1") + Q);
        }
      }

      this.length = RegGrp.count(expression);
      this.replacement = replacement;
      this.toString = K(expression);
    }
  }),

  count: function(expression) {
    // Count the number of sub-expressions in a RegExp/RegGrp.Item.
    expression = String(expression).replace(_RG_ESCAPE_CHARS, "").replace(_RG_ESCAPE_BRACKETS, "");
    return match(expression, _RG_BRACKETS).length;
  }
});

// =========================================================================
// lang/extend.js
// =========================================================================

function extend(object, source) { // or extend(object, key, value)
  if (object && source) {
    var proto = (typeof source == "function" ? Function : Object).prototype;
    // Add constructor, toString etc
    var i = _HIDDEN.length, key;
    if (prototyping) while (key = _HIDDEN[--i]) {
      var value = source[key];
      if (value != proto[key]) {
        if (_BASE.test(value)) {
          _override(object, key, value)
        } else {
          object[key] = value;
        }
      }
    }
    // Copy each of the source object's properties to the target object.
    for (key in source) if (proto[key] === undefined) {
      var value = source[key];
      // Check for method overriding.
      if (object[key] && typeof value == "function" && _BASE.test(value)) {
        _override(object, key, value);
      } else {
        object[key] = value;
      }
    }
  }
  return object;
};

function _override(object, name, method) {
  // Override an existing method.
  var ancestor = object[name];
  object[name] = function() {
    var previous = this.base;
    this.base = ancestor;
    var returnValue = method.apply(this, arguments);
    this.base = previous;
    return returnValue;
  };
};

function combine(keys, values) {
  // Combine two arrays to make a hash.
  if (!values) values = keys;
  var hash = {};
  for (var i in keys) hash[i] = values[i];
  return hash;
};

function format(string) {
  // Replace %n with arguments[n].
  // e.g. format("%1 %2%3 %2a %1%3", "she", "se", "lls");
  // ==> "she sells sea shells"
  // Only %1 - %9 supported.
  var args = arguments;
  var _FORMAT = new RegExp("%([1-" + arguments.length + "])", "g");
  return String(string).replace(_FORMAT, function(match, index) {
    return index < args.length ? args[index] : match;
  });
};

function match(string, expression) {
  // Same as String.match() except that this function will return an empty
  // array if there is no match.
  return String(string).match(expression) || [];
};

function rescape(string) {
  // Make a string safe for creating a RegExp.
  return String(string).replace(_RESCAPE, "\\$1");
};

// http://blog.stevenlevithan.com/archives/faster-trim-javascript
function trim(string) {
  return String(string).replace(_LTRIM, "").replace(_RTRIM, "");
};

function K(k) {
  return function() {
    return k;
  };
};
