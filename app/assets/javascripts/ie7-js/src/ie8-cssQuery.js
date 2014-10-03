
// =========================================================================
// ie8-cssQuery.js
// =========================================================================

IE7._isEmpty = function(element) {
  element = element.firstChild;
  while (element) {
    if (element.nodeType == 3 || (element.nodeType == 1 && element.nodeName != "!")) return false;
    element = element.nextSibling;
  }
  return true;
};

IE7._isLang = function(element, code) {
  while (element && !element.getAttribute("lang")) element = element.parentNode;
  return element && new RegExp("^" + rescape(code), "i").test(element.getAttribute("lang"));
};

function _nthChild(match, args, position, last) {
  // ugly but it works...
  last = /last/i.test(match) ? last + "+1-" : "";
  if (!isNaN(args)) args = "0n+" + args;
  else if (args == "even") args = "2n";
  else if (args == "odd") args = "2n+1";
  args = args.split("n");
  var a = args[0] ? (args[0] == "-") ? -1 : parseInt(args[0]) : 1;
  var b = parseInt(args[1]) || 0;
  var negate = a < 0;
  if (negate) {
    a = -a;
    if (a == 1) b++;
  }
  var query = format(a == 0 ? "%3%7" + (last + b) : "(%4%3-%2)%6%1%70%5%4%3>=%2", a, b, position, last, "&&", "%", "==");
  if (negate) query = "!(" + query + ")";
  return query;
};

_PSEUDO_CLASSES = {
  "link":          "e%1.currentStyle['ie7-link']=='link'",
  "visited":       "e%1.currentStyle['ie7-link']=='visited'",
  "checked":       "e%1.checked",
  "contains":      "e%1.innerText.indexOf('%2')!=-1",
  "disabled":      "e%1.isDisabled",
  "empty":         "IE7._isEmpty(e%1)",
  "enabled":       "e%1.disabled===false",
  "first-child":   "!IE7._getPreviousElementSibling(e%1)",
  "lang":          "IE7._isLang(e%1,'%2')",
  "last-child":    "!IE7._getNextElementSibling(e%1)",
  "only-child":    "!IE7._getPreviousElementSibling(e%1)&&!IE7._getNextElementSibling(e%1)",
  "target":        "e%1.id==location.hash.slice(1)",
  "indeterminate": "e%1.indeterminate"
};


// register a node and index its children
IE7._register = function(element) {
  if (element.rows) {
    element.ie7_length = element.rows.length;
    element.ie7_lookup = "rowIndex";
  } else if (element.cells) {
    element.ie7_length = element.cells.length;
    element.ie7_lookup = "cellIndex";
  } else if (element.ie7_indexed != IE7._indexed) {
    var index = 0;
    var child = element.firstChild;
    while (child) {
      if (child.nodeType == 1 && child.nodeName != "!") {
        child.ie7_index = ++index;
      }
      child = child.nextSibling;
    }
    element.ie7_length = index;
    element.ie7_lookup = "ie7_index";
  }
  element.ie7_indexed = IE7._indexed;
  return element;
};

var keys = cssParser[_KEYS];
var pseudoClass = keys[keys.length - 1];
keys.length--;

cssParser.merge({
  ":not\\((\\*|[\\w-]+)?([^)]*)\\)": function(match, tagName, filters) { // :not pseudo class
    var replacement = (tagName && tagName != "*") ? format("if(e%1.nodeName=='%2'){", _index, tagName.toUpperCase()) : "";
    replacement += cssParser.exec(filters);
    return "if(!" + replacement.slice(2, -1).replace(/\)\{if\(/g, "&&") + "){";
  },
  
  ":nth(-last)?-child\\(([^)]+)\\)": function(match, last, args) { // :nth-child pseudo classes
    _wild = false;
    last = format("e%1.parentNode.ie7_length", _index);
    var replacement = "if(p%1!==e%1.parentNode)p%1=IE7._register(e%1.parentNode);";
    replacement += "var i=e%1[p%1.ie7_lookup];if(p%1.ie7_lookup!='ie7_index')i++;if(";
    return format(replacement, _index) + _nthChild(match, args, "i", last) + "){";
  }
});

keys.push(pseudoClass);
