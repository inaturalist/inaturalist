
// =========================================================================
// ie7-cssQuery.js
// =========================================================================

function cssQuery(selector, context, single) {
  if (!_cache[selector]) {
    reg = []; // store for RegExp objects
    var fn = "";
    var selectors = cssParser.escape(selector).split(",");
    for (var i = 0; i < selectors.length; i++) {
      _wild = _index = _list = 0; // reset
      _duplicate = selectors.length > 1 ? 2 : 0; // reset
      var block = cssParser.exec(selectors[i]) || "if(0){";
      if (_wild) { // IE's pesky comment nodes
        block += format("if(e%1.nodeName!='!'){", _index);
      }
      // check for duplicates before storing results
      var store = _duplicate > 1 ? _TEST : "";
      block += format(store + _STORE, _index);
      // add closing braces
      block += Array(match(block, /\{/g).length + 1).join("}");
      fn += block;
    }
    eval(format(_FN, reg) + cssParser.unescape(fn) + "return s?null:r}");
    _cache[selector] = _selectorFunction;
  }
  return _cache[selector](context || document, single);
};

var _MSIE5 = appVersion < 6;

var _EVALUATED = /^(href|src)$/;
var _ATTRIBUTES = {
  "class": "className",
  "for": "htmlFor"
};

IE7._indexed = 1;

IE7._byId = function(document, id) {
  var result = document.all[id] || null;
  // returns a single element or a collection
  if (!result || result.id == id) return result;
  // document.all has returned a collection of elements with name/id
  for (var i = 0; i < result.length; i++) {
    if (result[i].id == id) return result[i];
  }
  return null;
};

IE7._getAttribute = function(element, name) {
  if (name == "src" && element.pngSrc) return element.pngSrc;
  
  var attribute = _MSIE5 ? (element.attributes[name] || element.attributes[_ATTRIBUTES[name.toLowerCase()]]) : element.getAttributeNode(name);
  if (attribute && (attribute.specified || name == "value")) {
    if (_EVALUATED.test(name)) {
      return element.getAttribute(name, 2);
    } else if (name == "class") {
     return element.className.replace(/\sie7_\w+/g, "");
    } else if (name == "style") {
     return element.style.cssText;
    } else {
     return attribute.nodeValue;
    }
  }
  return null;
};

var names = "colSpan,rowSpan,vAlign,dateTime,accessKey,tabIndex,encType,maxLength,readOnly,longDesc";
// Convert the list of strings to a hash, mapping the lowercase name to the camelCase name.
extend(_ATTRIBUTES, combine(names.toLowerCase().split(","), names.split(",")));

IE7._getNextElementSibling = function(node) {
  // return the next element to the supplied element
  //  nextSibling is not good enough as it might return a text or comment node
  while (node && (node = node.nextSibling) && (node.nodeType != 1 || node.nodeName == "!")) continue;
  return node;
};

IE7._getPreviousElementSibling = function(node) {
  // return the previous element to the supplied element
  while (node && (node = node.previousSibling) && (node.nodeType != 1 || node.nodeName == "!")) continue;
  return node;
};

// =========================================================================
// CSSParser
// =========================================================================

var IMPLIED_ASTERISK = /([\s>+~,]|[^(]\+|^)([#.:\[])/g,
    IMPLIED_SPACE =    /(^|,)([^\s>+~])/g,
    WHITESPACE =       /\s*([\s>+~(),]|^|$)\s*/g,
    WILD_CARD =        /\s\*\s/g;;

var CSSParser = RegGrp.extend({
  constructor: function(items) {
    this.base(items);
    this.sorter = new RegGrp;
    this.sorter.add(/:not\([^)]*\)/, RegGrp.IGNORE);
    this.sorter.add(/([ >](\*|[\w-]+))([^: >+~]*)(:\w+-child(\([^)]+\))?)([^: >+~]*)/, "$1$3$6$4");
  },
  
  ignoreCase: true,

  escape: function(selector) {
    return this.optimise(this.format(selector));
  },

  format: function(selector) {
    return selector
      .replace(WHITESPACE, "$1")
      .replace(IMPLIED_SPACE, "$1 $2")
      .replace(IMPLIED_ASTERISK, "$1*$2");
  },

  optimise: function(selector) {
    // optimise wild card descendant selectors
    return this.sorter.exec(selector.replace(WILD_CARD, ">* "));
  },

  unescape: function(selector) {
    return decode(selector);
  }
});

// some constants
var _OPERATORS = {
  "":   "%1!=null",
  "=":  "%1=='%2'",
  "~=": /(^| )%1( |$)/,
  "|=": /^%1(-|$)/,
  "^=": /^%1/,
  "$=": /%1$/,
  "*=": /%1/
};

var _PSEUDO_CLASSES = {
  "first-child": "!IE7._getPreviousElementSibling(e%1)",
  "link":        "e%1.currentStyle['ie7-link']=='link'",
  "visited":     "e%1.currentStyle['ie7-link']=='visited'"
};

var _VAR = "var p%2=0,i%2,e%2,n%2=e%1.";
var _ID = "e%1.sourceIndex";
var _TEST = "var g=" + _ID + ";if(!p[g]){p[g]=1;";
var _STORE = "r[r.length]=e%1;if(s)return e%1;";
var _FN = "var _selectorFunction=function(e0,s){IE7._indexed++;var r=[],p={},reg=[%1],d=document;";
var reg; // a store for RexExp objects
var _index;
var _wild; // need to flag certain _wild card selectors as MSIE includes comment nodes
var _list; // are we processing a node _list?
var _duplicate; // possible duplicates?
var _cache = {}; // store parsed selectors

// a hideous parser
var cssParser = new CSSParser({
  " (\\*|[\\w-]+)#([\\w-]+)": function(match, tagName, id) { // descendant selector followed by ID
    _wild = false;
    var replacement = "var e%2=IE7._byId(d,'%4');if(e%2&&";
    if (tagName != "*") replacement += "e%2.nodeName=='%3'&&";
    replacement += "(e%1==d||e%1.contains(e%2))){";
    if (_list) replacement += format("i%1=n%1.length;", _list);
    return format(replacement, _index++, _index, tagName.toUpperCase(), id);
  },
  
  " (\\*|[\\w-]+)": function(match, tagName) { // descendant selector
    _duplicate++; // this selector may produce duplicates
    _wild = tagName == "*";
    var replacement = _VAR;
    // IE5.x does not support getElementsByTagName("*");
    replacement += (_wild && _MSIE5) ? "all" : "getElementsByTagName('%3')";
    replacement += ";for(i%2=0;(e%2=n%2[i%2]);i%2++){";
    return format(replacement, _index++, _list = _index, tagName.toUpperCase());
  },
  
  ">(\\*|[\\w-]+)": function(match, tagName) { // child selector
    var children = _list;
    _wild = tagName == "*";
    var replacement = _VAR;
    // use the children property for MSIE as it does not contain text nodes
    //  (but the children collection still includes comments).
    // the document object does not have a children collection
    replacement += children ? "children": "childNodes";
    if (!_wild && children) replacement += ".tags('%3')";
    replacement += ";for(i%2=0;(e%2=n%2[i%2]);i%2++){";
    if (_wild) {
      replacement += "if(e%2.nodeType==1){";
      _wild = _MSIE5;
    } else {
      if (!children) replacement += "if(e%2.nodeName=='%3'){";
    }
    return format(replacement, _index++, _list = _index, tagName.toUpperCase());
  },
  
  "\\+(\\*|[\\w-]+)": function(match, tagName) { // direct adjacent selector
    var replacement = "";
    if (_wild) replacement += "if(e%1.nodeName!='!'){";
    _wild = false;
    replacement += "e%1=IE7._getNextElementSibling(e%1);if(e%1";
    if (tagName != "*") replacement += "&&e%1.nodeName=='%2'";
    replacement += "){";
    return format(replacement, _index, tagName.toUpperCase());
  },
  
  "~(\\*|[\\w-]+)": function(match, tagName) { // indirect adjacent selector
    var replacement = "";
    if (_wild) replacement += "if(e%1.nodeName!='!'){";
    _wild = false;
    _duplicate = 2; // this selector may produce duplicates
    replacement += "while(e%1=e%1.nextSibling){if(e%1.ie7_adjacent==IE7._indexed)break;if(";
    if (tagName == "*") {
      replacement += "e%1.nodeType==1";
      if (_MSIE5) replacement += "&&e%1.nodeName!='!'";
    } else replacement += "e%1.nodeName=='%2'";
    replacement += "){e%1.ie7_adjacent=IE7._indexed;";
    return format(replacement, _index, tagName.toUpperCase());
  },
  
  "#([\\w-]+)": function(match, id) { // ID selector
    _wild = false;
    var replacement = "if(e%1.id=='%2'){";
    if (_list) replacement += format("i%1=n%1.length;", _list);
    return format(replacement, _index, id);
  },
  
  "\\.([\\w-]+)": function(match, className) { // class selector
    _wild = false;
    // store RegExp objects - slightly faster on IE
    reg.push(new RegExp("(^|\\s)" + rescape(className) + "(\\s|$)"));
    return format("if(e%1.className&&reg[%2].test(e%1.className)){", _index, reg.length - 1);
  },
  
  "\\[([\\w-]+)\\s*([^=]?=)?\\s*([^\\]]*)\\]": function(match, attr, operator, value) { // attribute selectors
    var alias = _ATTRIBUTES[attr] || attr;
    if (operator) {
      var getAttribute = "e%1.getAttribute('%2',2)";
      if (!_EVALUATED.test(attr)) {
        getAttribute = "e%1.%3||" + getAttribute;
      }
      attr = format("(" + getAttribute + ")", _index, attr, alias);
    } else {
      attr = format("IE7._getAttribute(e%1,'%2')", _index, attr);
    }
    var replacement = _OPERATORS[operator || ""] || "0";
    if (replacement && replacement.source) {
      reg.push(new RegExp(format(replacement.source, rescape(cssParser.unescape(value)))));
      replacement = "reg[%2].test(%1)";
      value = reg.length - 1;
    }
    return "if(" + format(replacement, attr, value) + "){";
  },
  
  ":+([\\w-]+)(\\(([^)]+)\\))?": function(match, pseudoClass, $2, args) { // pseudo class selectors
    pseudoClass = _PSEUDO_CLASSES[pseudoClass];
    return "if(" + (pseudoClass ? format(pseudoClass, _index, args || "")  : "0") + "){";
  }
});
