
// =========================================================================
// ie7-html.js
// =========================================================================

// default font-sizes
//HEADER += "h1{font-size:2em}h2{font-size:1.5em;}h3{font-size:1.17em;}h4{font-size:1em}h5{font-size:.83em}h6{font-size:.67em}";

IE7.HTML = new (Fix.extend({ // single instance  
  fixed: {},
  
  init: Undefined,
  
  addFix: function() {
    // fixes are a one-off, they are applied when the document is loaded
    this.fixes.push(arguments);
  },
  
  apply: function() {
    for (var i = 0; i < this.fixes.length; i++) {
      var match = cssQuery(this.fixes[i][0]);
      var fix = this.fixes[i][1];
      for (var j = 0; j < match.length; j++) fix(match[j]);
    }
  },
  
  addRecalc: function() {
    // recalcs occur whenever the document is refreshed using document.recalc()
    this.recalcs.push(arguments);
  },
  
  recalc: function() {
    // loop through the fixes
    for (var i = 0; i < this.recalcs.length; i++) {
      var match = cssQuery(this.recalcs[i][0]);
      var recalc = this.recalcs[i][1], element;
      var key = Math.pow(2, i);
      for (var j = 0; (element = match[j]); j++) {
        var uniqueID = element.uniqueID;
        if ((this.fixed[uniqueID] & key) == 0) {
          element = recalc(element) || element;
          this.fixed[uniqueID] |= key;
        }
      }
    }
  }
}));

if (appVersion < 7) {  
  // provide support for the <abbr> tag.
  //  this is a proper fix, it preserves the DOM structure and
  //  <abbr> elements report the correct tagName & namespace prefix
  document.createElement("abbr");
  
  // bind to the first child control
  IE7.HTML.addRecalc("label", function(label) {
    if (!label.htmlFor) {
      var firstChildControl = cssQuery("input,textarea", label, true);
      if (firstChildControl) {
        addEventHandler(label, "onclick", function() {
          firstChildControl.click();
        });
      }
    }
  });
}
