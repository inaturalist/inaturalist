
// =========================================================================
// ie7-dhtml.js
// =========================================================================

(function() {

  /* ---------------------------------------------------------------------
    This module is still in development and should not be used.
  --------------------------------------------------------------------- */
  
  // constants
  var PATTERNS = {
    width: "(width|paddingLeft|paddingRight|borderLeftWidth|borderRightWidth|borderLeftStyle|borderRightStyle)",
    height:  "(height|paddingTop|paddingBottom|borderTopHeight|borderBottomHeight|borderTopStyle|borderBottomStyle)"
  };
  
  var PROPERTY_NAMES = {
    width: "fixedWidth",
    height: "fixedHeight",
    right: "width",
    bottom: "height"
  };
  
  var DASH_LETTER = /-(\w)/g;
  var PROPERTY_NAME = /\w+/;
  
  IE7.CSS.extend({
    recalc: function() {
      this.base();
      for (var i = 0; i < this.recalcs.length; i++) {
        var recalc = this.recalcs[i];
        for (var j = 0; i < recalc[3].length; i++) {
          addPropertyChangeHandler(recalc[3][j], getPropertyName(recalc[2]), recalc[1]);
        }
      }
    }
  });
  
  function addPropertyChangeHandler(element, propertyName, fix) {
    addEventHandler(element, "onpropertychange", function() {
     var pattern = new RegExp("^style\\." + (PATTERNS[propertyName] || propertyName) + "$");
      if (pattern.test(event.propertyName)) {
        reset(element, propertyName);
        fix(element);
      }
    });
  };
  
  function getPropertyName(pattern) {
    return String(String(pattern).toLowerCase().replace(DASH_LETTER, function(match, letter) {
      return letter.toUpperCase();
    }).match(PROPERTY_NAME));
  };
  
  function reset(element, propertyName) {
    element.runtimeStyle[propertyName] = "";
    propertyName = PROPERTY_NAMES[propertyName]
    if (propertyName) element.runtimeStyle[propertyName] = "";
  };

})();
