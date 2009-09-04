
// =========================================================================
// ie7-oveflow.js
// =========================================================================

/* ---------------------------------------------------------------------

  This module alters the structure of the document.
  It may adversely affect other CSS rules. Be warned.

--------------------------------------------------------------------- */

var WRAPPER_STYLE = {
  backgroundColor: "transparent",
  backgroundImage: "none",
  backgroundPositionX: null,
  backgroundPositionY: null,
  backgroundRepeat: null,
  borderTopWidth: 0,
  borderRightWidth: 0,
  borderBottomWidth: 0,
  borderLeftStyle: "none",
  borderTopStyle: "none",
  borderRightStyle: "none",
  borderBottomStyle: "none",
  borderLeftWidth: 0,
  height: null,
  marginTop: 0,
  marginBottom: 0,
  marginRight: 0,
  marginLeft: 0,
  width: "100%"
};

IE7.CSS.addRecalc("overflow", "visible", function(element) {
  // don't do this again
  if (element.parentNode.ie7_wrapped) return;

  // if max-height is applied, makes sure it gets applied first
  if (IE7.Layout && element.currentStyle["max-height"] != "auto") {
    IE7.Layout.maxHeight(element);
  }

  if (element.currentStyle.marginLeft == "auto") element.style.marginLeft = 0;
  if (element.currentStyle.marginRight == "auto") element.style.marginRight = 0;

  var wrapper = document.createElement(ANON);
  wrapper.ie7_wrapped = element;
  for (var propertyName in WRAPPER_STYLE) {
    wrapper.style[propertyName] = element.currentStyle[propertyName];
    if (WRAPPER_STYLE[propertyName] != null) {
      element.runtimeStyle[propertyName] = WRAPPER_STYLE[propertyName];
    }
  }
  wrapper.style.display = "block";
  wrapper.style.position = "relative";
  element.runtimeStyle.position = "absolute";
  element.parentNode.insertBefore(wrapper, element);
  wrapper.appendChild(element);
});
