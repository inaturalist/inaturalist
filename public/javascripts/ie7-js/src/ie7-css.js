
// =========================================================================
// ie7-css.js
// =========================================================================

var HYPERLINK = /a(#[\w-]+)?(\.[\w-]+)?:(hover|active)/i;
var BRACE1 = /\s*\{\s*/, BRACE2 = /\s*\}\s*/, COMMA = /\s*\,\s*/;
var FIRST_LINE_LETTER = /(.*)(:first-(line|letter))/;

//var UNKNOWN = /UNKNOWN|([:.])\w+\1/i;

var styleSheets = document.styleSheets;

IE7.CSS = new (Fix.extend({ // single instance
  parser: new Parser,
  screen: "",
  print: "",
  styles: [],
  rules: [],
  pseudoClasses: appVersion < 7 ? "first\\-child" : "",
  dynamicPseudoClasses: {
    toString: function() {
      var strings = [];
      for (var pseudoClass in this) strings.push(pseudoClass);
      return strings.join("|");
    }
  },
  
  init: function() {
    var NONE = "^\x01$";
    var CLASS = "\\[class=?[^\\]]*\\]";
    var pseudoClasses = [];
    if (this.pseudoClasses) pseudoClasses.push(this.pseudoClasses);
    var dynamicPseudoClasses = this.dynamicPseudoClasses.toString(); 
    if (dynamicPseudoClasses) pseudoClasses.push(dynamicPseudoClasses);
    pseudoClasses = pseudoClasses.join("|");
    var unknown = appVersion < 7 ? ["[>+~[(]|([:.])\\w+\\1"] : [CLASS];
    if (pseudoClasses) unknown.push(":(" + pseudoClasses + ")");
    this.UNKNOWN = new RegExp(unknown.join("|") || NONE, "i");
    var complex = appVersion < 7 ? ["\\[[^\\]]+\\]|[^\\s(\\[]+\\s*[+~]"] : [CLASS];
    var complexRule = complex.concat();
    if (pseudoClasses) complexRule.push(":(" + pseudoClasses + ")");
    Rule.COMPLEX = new RegExp(complexRule.join("|") || NONE, "ig");
    if (this.pseudoClasses) complex.push(":(" + this.pseudoClasses + ")");
    DynamicRule.COMPLEX = new RegExp(complex.join("|") || NONE, "i");
    DynamicRule.MATCH = new RegExp(dynamicPseudoClasses ? "(.*):(" + dynamicPseudoClasses + ")(.*)" : NONE, "i");
    
    this.createStyleSheet();
    this.refresh();
  },
  
	addEventHandler: function() {
		addEventHandler.apply(null, arguments);
	},
  
  addFix: function(expression, replacement) {
    this.parser.add(expression, replacement);
  },
  
  addRecalc: function(propertyName, test, handler, replacement) {
    // recalcs occur whenever the document is refreshed using document.recalc()
    test = new RegExp("([{;\\s])" + propertyName + "\\s*:\\s*" + test + "[^;}]*");
    var id = this.recalcs.length;
    if (replacement) replacement = propertyName + ":" + replacement;
    this.addFix(test, function(match, $1) {
      return (replacement ? $1 + replacement : match) + ";ie7-" + match.slice(1) + ";ie7_recalc" + id + ":1";
    });
    this.recalcs.push(arguments);
    return id;
  },
  
  apply: function() {
    this.getInlineStyles();
    new StyleSheet("screen");
    this.trash();
  },
  
  createStyleSheet: function() {
    // create the IE7 style sheet
    this.styleSheet = document.createStyleSheet();
    // flag it so we can ignore it during parsing
    this.styleSheet.ie7 = true;
    this.styleSheet.owningElement.ie7 = true;
    this.styleSheet.cssText = HEADER;
  },
  
  getInlineStyles: function() {
    // load inline styles
    var styleSheets = document.getElementsByTagName("style"), styleSheet;
    for (var i = styleSheets.length - 1; (styleSheet = styleSheets[i]); i--) {
      if (!styleSheet.disabled && !styleSheet.ie7) {
        this.styles.push(styleSheet.innerHTML);
      }
    }
  },
  
  getText: function(styleSheet, path) {
    // explorer will trash unknown selectors (it converts them to "UNKNOWN").
    // so we must reload external style sheets (internal style sheets can have their text
    //  extracted through the innerHTML property).
      // load the style sheet text from an external file
    try {
      var cssText = styleSheet.cssText;
    } catch (e) {
      cssText = "";
    }
    if (httpRequest) cssText = loadFile(styleSheet.href, path) || cssText;
    return cssText;
  },
  
  recalc: function() {
    this.screen.recalc();
    // we're going to read through all style rules.
    //  certain rules have had ie7 properties added to them.
    //   e.g. p{top:0; ie7_recalc2:1; left:0}
    //  this flags a property in the rule as needing a fix.
    //  the selector text is then used to query the document.
    //  we can then loop through the results of the query
    //  and fix the elements.
    // we ignore the IE7 rules - so count them in the header
    var RECALCS = /ie7_recalc\d+/g;
    var start = HEADER.match(/[{,]/g).length;
    // only calculate screen fixes. print fixes don't show up anyway
    var stop = start + (this.screen.cssText.match(/\{/g)||"").length;
    var rules = this.styleSheet.rules, rule;
    var calcs, calc, elements, element, i, j, k, id;
    // loop through all rules
    for (i = start; i < stop; i++) {
      rule = rules[i];
      var cssText = rule.style.cssText;
      // search for the "ie7_recalc" flag (there may be more than one)
      if (rule && (calcs = cssText.match(RECALCS))) {
        // use the selector text to query the document
        elements = cssQuery(rule.selectorText);
        // if there are matching elements then loop
        //  through the recalc functions and apply them
        //  to each element
        if (elements.length) for (j = 0; j < calcs.length; j++) {
          // get the matching flag (e.g. ie7_recalc3)
          id = calcs[j];
          // extract the numeric id from the end of the flag
          //  and use it to index the collection of recalc
          //  functions
          calc = IE7.CSS.recalcs[id.slice(10)][2];
          for (k = 0; (element = elements[k]); k++) {
            // apply the fix
            if (element.currentStyle[id]) calc(element, cssText);
          }
        }
      }
    }
  },
  
  refresh: function() {
    this.styleSheet.cssText = HEADER + this.screen + this.print;
  },
  
  trash: function() {
    // trash the old style sheets
    for (var i = 0; i < styleSheets.length; i++) {
      if (!styleSheets[i].ie7) {
        try {
          var cssText = styleSheets[i].cssText;
        } catch (e) {
          cssText = "";
        }
        if (cssText) styleSheets[i].cssText = "";
      }
    }
  }
}));

// -----------------------------------------------------------------------
//  IE7 StyleSheet class
// -----------------------------------------------------------------------

var StyleSheet = Base.extend({
  constructor: function(media) {
    this.media = media;
    this.load();
    IE7.CSS[media] = this;
    IE7.CSS.refresh();
  },
  
  createRule: function(selector, cssText) {
    if (IE7.CSS.UNKNOWN.test(selector)) {
      var match;
      if (PseudoElement && (match = selector.match(PseudoElement.MATCH))) {
        return new PseudoElement(match[1], match[2], cssText);
      } else if (match = selector.match(DynamicRule.MATCH)) {
        if (!HYPERLINK.test(match[0]) || DynamicRule.COMPLEX.test(match[0])) {
          return new DynamicRule(selector, match[1], match[2], match[3], cssText);
        }
      } else return new Rule(selector, cssText);
    }
    return selector + " {" + cssText + "}";
  },
  
  getText: function() {
    // store for style sheet text
    var _inlineStyles = [].concat(IE7.CSS.styles);
    // parse media decalarations
    var MEDIA = /@media\s+([^{]*)\{([^@]+\})\s*\}/gi;
    var ALL = /\ball\b|^$/i, SCREEN = /\bscreen\b/i, PRINT = /\bprint\b/i;
    function _parseMedia(cssText, media) {
      _filterMedia.value = media;
      return cssText.replace(MEDIA, _filterMedia);
    };
    function _filterMedia(match, media, cssText) {
      media = _simpleMedia(media);
      switch (media) {
        case "screen":
        case "print":
          if (media != _filterMedia.value) return "";
        case "all":
          return cssText;
      }
      return "";
    };
    function _simpleMedia(media) {
      if (ALL.test(media)) return "all";
      else if (SCREEN.test(media)) return (PRINT.test(media)) ? "all" : "screen";
      else if (PRINT.test(media)) return "print";
    };
    var self = this;
    function _getCSSText(styleSheet, path, media, level) {
      var cssText = "";
      if (!level) {
        media = _simpleMedia(styleSheet.media);
        level = 0;
      }
      if (media == "all" || media == self.media) {
        // IE only allows importing style sheets three levels deep.
        // it will crash if you try to access a level below this
        if (level < 3) {
          // loop through imported style sheets
          for (var i = 0; i < styleSheet.imports.length; i++) {
            // call this function recursively to get all imported style sheets
            cssText += _getCSSText(styleSheet.imports[i], getPath(styleSheet.href, path), media, level + 1);
          }
        }
        // retrieve inline style or load an external style sheet
        cssText += encode(styleSheet.href ? _loadStyleSheet(styleSheet, path) : _inlineStyles.pop() || "");
        cssText = _parseMedia(cssText, self.media);
      }
      return cssText;
    };
    // store loaded cssText URLs
    var fileCache = {};
    // load an external style sheet
    function _loadStyleSheet(styleSheet, path) {
      var url = makePath(styleSheet.href, path);
      // if the style sheet has already loaded then don't duplicate it
      if (fileCache[url]) return "";
      // load from source
      fileCache[url] = (styleSheet.disabled) ? "" :
        _fixUrls(IE7.CSS.getText(styleSheet, path), getPath(styleSheet.href, path));
      return fileCache[url];
    };
    // fix css paths
    // we're lumping all css text into one big style sheet so relative
    //  paths have to be fixed. this is necessary anyway because of other
    //  explorer bugs.
    var URL = /(url\s*\(\s*['"]?)([\w\.]+[^:\)]*['"]?\))/gi;
    function _fixUrls(cssText, pathname) {
      // hack & slash
      return cssText.replace(URL, "$1" + pathname.slice(0, pathname.lastIndexOf("/") + 1) + "$2");
    };

    // load all style sheets in the document
    for (var i = 0; i < styleSheets.length; i++) {
      if (!styleSheets[i].disabled && !styleSheets[i].ie7) {
        this.cssText += _getCSSText(styleSheets[i]);
      }
    }
  },
  
  load: function() {
    this.cssText = "";
    this.getText();
    this.parse();
    this.cssText = decode(this.cssText);
    fileCache = {};
  },
  
  parse: function() {
    this.cssText = IE7.CSS.parser.exec(this.cssText);
    
    // parse the style sheet
    var offset = IE7.CSS.rules.length;
    var rules = this.cssText.split(BRACE2), rule;
    var selectors, cssText, i, j;
    for (i = 0; i < rules.length; i++) {
      rule = rules[i].split(BRACE1);
      selectors = rule[0].split(COMMA);
      cssText = rule[1];
      for (j = 0; j < selectors.length; j++) {
        selectors[j] = cssText ? this.createRule(selectors[j], cssText) : "";
      }
      rules[i] = selectors.join("\n");
    }
    this.cssText = rules.join("\n");
    this.rules = IE7.CSS.rules.slice(offset);
  },
  
  recalc: function() {
    var rule, i;
    for (i = 0; (rule = this.rules[i]); i++) rule.recalc();
  },
  
  toString: function() {
    return "@media " + this.media + "{" + this.cssText + "}";
  }
});

var PseudoElement;

// -----------------------------------------------------------------------
// IE7 style rules
// -----------------------------------------------------------------------

var Rule = IE7.Rule = Base.extend({
  // properties
  constructor: function(selector, cssText) {
    this.id = IE7.CSS.rules.length;
    this.className = Rule.PREFIX + this.id;
    selector = selector.match(FIRST_LINE_LETTER) || selector || "*";
    this.selector = selector[1] || selector;
    this.selectorText = this.parse(this.selector) + (selector[2] || "");
    this.cssText = cssText;
    this.MATCH = new RegExp("\\s" + this.className + "(\\s|$)", "g");
    IE7.CSS.rules.push(this);
    this.init();
  },
  
  init: Undefined,
  
  add: function(element) {
    // allocate this class
    element.className += " " + this.className;
  },
  
  recalc: function() {
    // execute the underlying css query for this class
    var match = cssQuery(this.selector);
    // add the class name for all matching elements
    for (var i = 0; i < match.length; i++) this.add(match[i]);
  },

  parse: function(selector) {
    // attempt to preserve specificity for "loose" parsing by
    //  removing unknown tokens from a css selector but keep as
    //  much as we can..
    var simple = selector.replace(Rule.CHILD, " ").replace(Rule.COMPLEX, "");
    if (appVersion < 7) simple = simple.replace(Rule.MULTI, "");
    var tags = match(simple, Rule.TAGS).length - match(selector, Rule.TAGS).length;
    var classes = match(simple, Rule.CLASSES).length - match(selector, Rule.CLASSES).length + 1;
    while (classes > 0 && Rule.CLASS.test(simple)) {
      simple = simple.replace(Rule.CLASS, "");
      classes--;
    }
    while (tags > 0 && Rule.TAG.test(simple)) {
      simple = simple.replace(Rule.TAG, "$1*");
      tags--;
    }
    simple += "." + this.className;
    classes = Math.min(classes, 2);
    tags = Math.min(tags, 2);
    var score = -10 * classes - tags;
    if (score > 0) {
      simple = simple + "," + Rule.MAP[score] + " " + simple;
    }
    return simple;
  },
  
  remove: function(element) {
    // deallocate this class
    element.className = element.className.replace(this.MATCH, "$1");
  },
  
  toString: function() {
    return format("%1 {%2}", this.selectorText, this.cssText);
  }
}, {
  CHILD: />/g,
  CLASS: /\.[\w-]+/,
  CLASSES: /[.:\[]/g,
  MULTI: /(\.[\w-]+)+/g,
  PREFIX: "ie7_class",
  TAG: /^\w+|([\s>+~])\w+/,
  TAGS: /^\w|[\s>+~]\w/g,
  MAP: {
    1:  "html",
    2:  "html body",
    10: ".ie7_html",
    11: "html.ie7_html",
    12: "html.ie7_html body",
    20: ".ie7_html .ie7_body",
    21: "html.ie7_html .ie7_body",
    22: "html.ie7_html body.ie7_body"
  }
});

// -----------------------------------------------------------------------
// IE7 dynamic style
// -----------------------------------------------------------------------

// object properties:
// attach: the element that an event handler will be attached to
// target: the element that will have the IE7 class applied

var DynamicRule = Rule.extend({
  // properties
  constructor: function(selector, attach, dynamicPseudoClass, target, cssText) {
    // initialise object properties
    this.attach = attach || "*";
    this.dynamicPseudoClass = IE7.CSS.dynamicPseudoClasses[dynamicPseudoClass];
    this.target = target;
    this.base(selector, cssText);
  },
  
  recalc: function() {
    // execute the underlying css query for this class
    var attaches = cssQuery(this.attach), attach;
    // process results
    for (var i = 0; attach = attaches[i]; i++) {
      // retrieve the event handler's target element(s)
      var target = this.target ? cssQuery(this.target, attach) : [attach];
      // attach event handlers for dynamic pseudo-classes
      if (target.length) this.dynamicPseudoClass.apply(attach, target, this);
    }
  }
});

// -----------------------------------------------------------------------
//  IE7 dynamic pseudo-classes
// -----------------------------------------------------------------------

var DynamicPseudoClass = Base.extend({
  constructor: function(name, apply) {
    this.name = name;
    this.apply = apply;
    this.instances = {};
    IE7.CSS.dynamicPseudoClasses[name] = this;
  },
  
  register: function(instance) {
    // an "instance" is actually an Arguments object
    var _class = instance[2];
    instance.id = _class.id + instance[0].uniqueID;
    if (!this.instances[instance.id]) {
      var target = instance[1], j;
      for (j = 0; j < target.length; j++) _class.add(target[j]);
      this.instances[instance.id] = instance;
    }
  },
  
  unregister: function(instance) {
    if (this.instances[instance.id]) {
      var _class = instance[2];
      var target = instance[1], j;
      for (j = 0; j < target.length; j++) _class.remove(target[j]);
      delete this.instances[instance.id];
    }
  }
});
  
// -----------------------------------------------------------------------
// dynamic pseudo-classes
// -----------------------------------------------------------------------

if (appVersion < 7) {
  var Hover = new DynamicPseudoClass("hover", function(element) {
    var instance = arguments;
    IE7.CSS.addEventHandler(element, appVersion < 5.5 ? "onmouseover" : "onmouseenter", function() {
      Hover.register(instance);
    });
    IE7.CSS.addEventHandler(element, appVersion < 5.5 ? "onmouseout" : "onmouseleave", function() {
      Hover.unregister(instance);
    });
  });
  
  // globally trap the mouseup event (thanks Martijn!)
  addEventHandler(document, "onmouseup", function() {
    var instances = Hover.instances;
    for (var i in instances)
      if (!instances[i][0].contains(event.srcElement))
        Hover.unregister(instances[i]);
  });
}
