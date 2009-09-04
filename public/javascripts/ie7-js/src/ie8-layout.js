
// =========================================================================
// ie8-layout.js
// =========================================================================

IE7.CSS.addRecalc("border-spacing", NUMERIC, function(element) {
  if (element.currentStyle.borderCollapse != "collapse") {
    element.cellSpacing = getPixelValue(element, element.currentStyle["border-spacing"]);
  }
});
IE7.CSS.addRecalc("box-sizing", "content-box", IE7.Layout.boxSizing);
IE7.CSS.addRecalc("box-sizing", "border-box", IE7.Layout.borderBox);
