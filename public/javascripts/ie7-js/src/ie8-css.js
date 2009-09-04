
// =========================================================================
// ie8-css.js
// =========================================================================

var BRACKETS = "\\([^)]*\\)";

if (IE7.CSS.pseudoClasses) IE7.CSS.pseudoClasses += "|";
IE7.CSS.pseudoClasses += "before|after|last\\-child|only\\-child|empty|root|" +
  "not|nth\\-child|nth\\-last\\-child|contains|lang".split("|").join(BRACKETS + "|") + BRACKETS;

// pseudo-elements can be declared with a double colon
encoder.add(/::/, ":");

// -----------------------------------------------------------------------
// propertyName: inherit;
// -----------------------------------------------------------------------

IE7.CSS.addRecalc("[\\w-]+", "inherit", function(element, cssText) {
  if (element.parentElement) {
    var inherited = cssText.match(/[\w-]+\s*:\s*inherit/g);
    for (var i = 0; i < inherited.length; i++) {
      var propertyName = inherited[i].replace(/ie7\-|\s*:\s*inherit/g, "").replace(/\-([a-z])/g, function(match, chr) {
        return chr.toUpperCase()
      });
      element.runtimeStyle[propertyName] = element.parentElement.currentStyle[propertyName];
    }
  }
});

// -----------------------------------------------------------------------
// dynamic pseudo-classes
// -----------------------------------------------------------------------

var Focus = new DynamicPseudoClass("focus", function(element) {
  var instance = arguments;
  
  IE7.CSS.addEventHandler(element, "onfocus", function() {
    Focus.unregister(instance); // in case it starts with focus
    Focus.register(instance);
  });
  
  IE7.CSS.addEventHandler(element, "onblur", function() {
    Focus.unregister(instance);
  });
  
  // check the active element for initial state
  if (element == document.activeElement) {
    Focus.register(instance)
  }
});

var Active = new DynamicPseudoClass("active", function(element) {
  var instance = arguments;
  IE7.CSS.addEventHandler(element, "onmousedown", function() {
    Active.register(instance);
  });
});

// globally trap the mouseup event (thanks Martijn!)
addEventHandler(document, "onmouseup", function() {
  var instances = Active.instances;
  for (var i in instances) Active.unregister(instances[i]);
});

// :checked
var Checked = new DynamicPseudoClass("checked", function(element) {
  if (typeof element.checked != "boolean") return;
  var instance = arguments;
  IE7.CSS.addEventHandler(element, "onpropertychange", function() {
    if (event.propertyName == "checked") {
      if (element.checked) Checked.register(instance);
      else Checked.unregister(instance);
    }
  });
  // check current checked state
  if (element.checked) Checked.register(instance);
});

// :enabled
var Enabled = new DynamicPseudoClass("enabled", function(element) {
  if (typeof element.disabled != "boolean") return;
  var instance = arguments;
  IE7.CSS.addEventHandler(element, "onpropertychange", function() {
    if (event.propertyName == "disabled") {
      if (!element.isDisabled) Enabled.register(instance);
      else Enabled.unregister(instance);
    }
  });
  // check current disabled state
  if (!element.isDisabled) Enabled.register(instance);
});

// :disabled
var Disabled = new DynamicPseudoClass("disabled", function(element) {
  if (typeof element.disabled != "boolean") return;
  var instance = arguments;
  IE7.CSS.addEventHandler(element, "onpropertychange", function() {
    if (event.propertyName == "disabled") {
      if (element.isDisabled) Disabled.register(instance);
      else Disabled.unregister(instance);
    }
  });
  // check current disabled state
  if (element.isDisabled) Disabled.register(instance);
});

// :indeterminate (Kevin Newman)
var Indeterminate = new DynamicPseudoClass("indeterminate", function(element) {
  if (typeof element.indeterminate != "boolean") return;
  var instance = arguments;
  IE7.CSS.addEventHandler(element, "onpropertychange", function() {
    if (event.propertyName == "indeterminate") {
      if (element.indeterminate) Indeterminate.register(instance);
      else Indeterminate.unregister(instance);
    }
  });
  IE7.CSS.addEventHandler(element, "onclick", function() {
    Indeterminate.unregister(instance);
  });
  // clever Kev says no need to check this up front
});

// :target
var Target = new DynamicPseudoClass("target", function(element) {
  var instance = arguments;
  // if an element has a tabIndex then it can become "active".
  //  The default is zero anyway but it works...
  if (!element.tabIndex) element.tabIndex = 0;
  // this doesn't detect the back button. I don't know how to do that :-(
  IE7.CSS.addEventHandler(document, "onpropertychange", function() {
    if (event.propertyName == "activeElement") {
      if (element.id && element.id == location.hash.slice(1)) Target.register(instance);
      else Target.unregister(instance);
    }
  });
  // check the current location
  if (element.id && element.id == location.hash.slice(1)) Target.register(instance);
});

// -----------------------------------------------------------------------
// IE7 pseudo elements
// -----------------------------------------------------------------------

// constants
var ATTR = /^attr/;
var URL = /^url\s*\(\s*([^)]*)\)$/;
var POSITION_MAP = {
  before0: "beforeBegin",
  before1: "afterBegin",
  after0: "afterEnd",
  after1: "beforeEnd"
};

var PseudoElement = IE7.PseudoElement = Rule.extend({
  constructor: function(selector, position, cssText) {
    // initialise object properties
    this.position = position;
    var content = cssText.match(PseudoElement.CONTENT), match, entity;
    if (content) {
      content = content[1];
      match = content.split(/\s+/);
      for (var i = 0; (entity = match[i]); i++) {
        match[i] = ATTR.test(entity) ? {attr: entity.slice(5, -1)} :
          (entity.charAt(0) == "'") ? getString(entity) : decode(entity);
      }
      content = match;
    }
    this.content = content;
    // CSS text needs to be decoded immediately
    this.base(selector, decode(cssText));
  },
  
  init: function() {
    // execute the underlying css query for this class
    this.match = cssQuery(this.selector);
    for (var i = 0; i < this.match.length; i++) {
      var runtimeStyle = this.match[i].runtimeStyle;
      if (!runtimeStyle[this.position]) runtimeStyle[this.position] = {cssText:""};
      runtimeStyle[this.position].cssText += ";" + this.cssText;
      if (this.content != null) runtimeStyle[this.position].content = this.content;
    }
  },
  
  create: function(target) {
    var generated = target.runtimeStyle[this.position];
    if (generated) {
      // copy the array of values
      var content = [].concat(generated.content || "");
      for (var j = 0; j < content.length; j++) {
        if (typeof content[j] == "object") {
          content[j] = target.getAttribute(content[j].attr);
        }
      }
      content = content.join("");
      var url = content.match(URL);
      var cssText = "overflow:hidden;" + generated.cssText.replace(/'/g, '"');
      if (target.currentStyle.styleFloat != "none") {
        //cssText = cssText.replace(/display\s*:\s*block/, "display:inline-block");
      }
      var position = POSITION_MAP[this.position + Number(target.canHaveChildren)];
      var id = 'ie7_pseudo' + PseudoElement.count++;
      target.insertAdjacentHTML(position, format(PseudoElement.ANON, this.className, id, cssText, url ? "" : content));
      if (url) {
        var pseudoElement = document.getElementById(id);
        pseudoElement.src = getString(url[1]);
        addFilter(pseudoElement, "crop");
      }
      target.runtimeStyle[this.position] = null;
    }
  },
  
  recalc: function() {
    if (this.content == null) return;
    for (var i = 0; i < this.match.length; i++) {
      this.create(this.match[i]);
    }
  },

  toString: function() {
    return "." + this.className + "{display:inline}";
  }
}, {  
  CONTENT: /content\s*:\s*([^;]*)(;|$)/,
  ANON: "<ie7:! class='ie7_anon %1' id=%2 style='%3'>%4</ie7:!>",
  MATCH: /(.*):(before|after).*/,
  
  count: 0
});
