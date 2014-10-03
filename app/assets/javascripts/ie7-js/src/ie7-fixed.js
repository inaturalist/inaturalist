
// =========================================================================
// ie7-fixed.js
// =========================================================================

new function(_) {
  if (appVersion >= 7) return;
  
  // some things to consider for this hack.
  // the document body requires a fixed background. even if
  //  it is just a blank image.
  // you have to use setExpression instead of onscroll, this
  //  together with a fixed body background helps avoid the
  //  annoying screen flicker of other solutions.
  
  IE7.CSS.addRecalc("position", "fixed", _positionFixed, "absolute");
  IE7.CSS.addRecalc("background(-attachment)?", "[^};]*fixed", _backgroundFixed);
  
  // scrolling is relative to the documentElement (HTML tag) when in
  //  standards mode, otherwise it's relative to the document body
  var $viewport = quirksMode ? "body" : "documentElement";
  
  function _fixBackground() {
    // this is required by both position:fixed and background-attachment:fixed.
    // it is necessary for the document to also have a fixed background image.
    // we can fake this with a blank image if necessary
    if (body.currentStyle.backgroundAttachment != "fixed") {
      if (body.currentStyle.backgroundImage == "none") {
        body.runtimeStyle.backgroundRepeat = "no-repeat";
        body.runtimeStyle.backgroundImage = "url(" + BLANK_GIF + ")"; // dummy
      }
      body.runtimeStyle.backgroundAttachment = "fixed";
    }
    _fixBackground = Undefined;
  };
  
  var _tmp = createTempElement("img");
  
  function _isFixed(element) {
    return element ? isFixed(element) || _isFixed(element.parentElement) : false;
  };
  
  function _setExpression(element, propertyName, expression) {
    setTimeout("document.all." + element.uniqueID + ".runtimeStyle.setExpression('" + propertyName + "','" + expression + "')", 0);
  };
  
  // -----------------------------------------------------------------------
  //  backgroundAttachment: fixed
  // -----------------------------------------------------------------------
  
  function _backgroundFixed(element) {
    if (register(_backgroundFixed, element, element.currentStyle.backgroundAttachment == "fixed" && !element.contains(body))) {
      _fixBackground();
      bgLeft(element);
      bgTop(element);
      _backgroundPosition(element);
    }
  };
  
  function _backgroundPosition(element) {
    _tmp.src = element.currentStyle.backgroundImage.slice(5, -2);
    var parentElement = element.canHaveChildren ? element : element.parentElement;
    parentElement.appendChild(_tmp);
    setOffsetLeft(element);
    setOffsetTop(element);
    parentElement.removeChild(_tmp);
  };
  
  function bgLeft(element) {
    element.style.backgroundPositionX = element.currentStyle.backgroundPositionX;
    if (!_isFixed(element)) {
      _setExpression(element, "backgroundPositionX", "(parseInt(runtimeStyle.offsetLeft)+document." + $viewport + ".scrollLeft)||0");
    }
  };
  eval(rotate(bgLeft));
  
  function setOffsetLeft(element) {
    var propertyName = _isFixed(element) ? "backgroundPositionX" : "offsetLeft";
    element.runtimeStyle[propertyName] =
      getOffsetLeft(element, element.style.backgroundPositionX) -
      element.getBoundingClientRect().left - element.clientLeft + 2;
  };
  eval(rotate(setOffsetLeft));
  
  function getOffsetLeft(element, position) {
    switch (position) {
      case "left":
      case "top":
        return 0;
      case "right":
      case "bottom":
        return viewport.clientWidth - _tmp.offsetWidth;
      case "center":
        return (viewport.clientWidth - _tmp.offsetWidth) / 2;
      default:
        if (PERCENT.test(position)) {
          return parseInt((viewport.clientWidth - _tmp.offsetWidth) * parseFloat(position) / 100);
        }
        _tmp.style.left = position;
        return _tmp.offsetLeft;
    }
  };
  eval(rotate(getOffsetLeft));
  
  // -----------------------------------------------------------------------
  //  position: fixed
  // -----------------------------------------------------------------------
  
  function _positionFixed(element) {
    if (register(_positionFixed, element, isFixed(element))) {
      setOverrideStyle(element, "position",  "absolute");
      setOverrideStyle(element, "left",  element.currentStyle.left);
      setOverrideStyle(element, "top",  element.currentStyle.top);
      _fixBackground();
      IE7.Layout.fixRight(element);
      _foregroundPosition(element);
    }
  };
  
  function _foregroundPosition(element, recalc) {
    positionTop(element, recalc);
    positionLeft(element, recalc, true);
    if (!element.runtimeStyle.autoLeft && element.currentStyle.marginLeft == "auto" &&
      element.currentStyle.right != "auto") {
      var left = viewport.clientWidth - getPixelWidth(element, element.currentStyle.right) -
        getPixelWidth(element, element.runtimeStyle._left) - element.clientWidth;
      if (element.currentStyle.marginRight == "auto") left = parseInt(left / 2);
      if (_isFixed(element.offsetParent)) element.runtimeStyle.pixelLeft += left;
      else element.runtimeStyle.shiftLeft = left;
    }
    clipWidth(element);
    clipHeight(element);
  };

  function clipWidth(element) {
    var fixWidth = element.runtimeStyle.fixWidth;
    element.runtimeStyle.borderRightWidth = "";
    element.runtimeStyle.width = fixWidth ? getPixelWidth(element, fixWidth) : "";
    if (element.currentStyle.width != "auto") {
      var rect = element.getBoundingClientRect();
      var width = element.offsetWidth - viewport.clientWidth + rect.left - 2;
      if (width >= 0) {
        element.runtimeStyle.borderRightWidth = "0px";
        width = Math.max(getPixelValue(element, element.currentStyle.width) - width, 0);
        setOverrideStyle(element, "width",  width);
        return width;
      }
    }
  };
  eval(rotate(clipWidth));
  
  function positionLeft(element, recalc) {
    // if the element's width is in % units then it must be recalculated
    //  with respect to the viewport
    if (!recalc && PERCENT.test(element.currentStyle.width)) {
      element.runtimeStyle.fixWidth = element.currentStyle.width;
    }
    if (element.runtimeStyle.fixWidth) {
      element.runtimeStyle.width = getPixelWidth(element, element.runtimeStyle.fixWidth);
    }
    //if (recalc) {
    //  // if the element is fixed on the right then no need to recalculate
    //  if (!element.runtimeStyle.autoLeft) return;
    //} else {
      element.runtimeStyle.shiftLeft = 0;
      element.runtimeStyle._left = element.currentStyle.left;
      // is the element fixed on the right?
      element.runtimeStyle.autoLeft = element.currentStyle.right != "auto" &&
        element.currentStyle.left == "auto";
    //}
    // reset the element's "left" value and get it's natural position
    element.runtimeStyle.left = "";
    element.runtimeStyle.screenLeft = getScreenLeft(element);
    element.runtimeStyle.pixelLeft = element.runtimeStyle.screenLeft;
    // if the element is contained by another fixed element then there is no need to
    //  continually recalculate it's left position
    if (!recalc && !_isFixed(element.offsetParent)) {
      // onsrcoll produces jerky movement, so we use an expression
      _setExpression(element, "pixelLeft", "runtimeStyle.screenLeft+runtimeStyle.shiftLeft+document." + $viewport + ".scrollLeft");
    }
  };
  // clone this function so we can do "top"
  eval(rotate(positionLeft));
  
  // I've forgotten how this works...
  function getScreenLeft(element) { // thanks to kevin newman (captainn)
    var screenLeft = element.offsetLeft, nested = 1;
    if (element.runtimeStyle.autoLeft) {
      screenLeft = viewport.clientWidth - element.offsetWidth - getPixelWidth(element, element.currentStyle.right);
    }
    // accommodate margins
    if (element.currentStyle.marginLeft != "auto") {
      screenLeft -= getPixelWidth(element, element.currentStyle.marginLeft);
    }
    while (element = element.offsetParent) {
      if (element.currentStyle.position != "static") nested = -1;
      screenLeft += element.offsetLeft * nested;
    }
    return screenLeft;
  };
  eval(rotate(getScreenLeft));
  
  function getPixelWidth(element, value) {
    return PERCENT.test(value) ? parseInt(parseFloat(value) / 100 * viewport.clientWidth) : getPixelValue(element, value);
  };
  eval(rotate(getPixelWidth));
  
  // -----------------------------------------------------------------------
  //  capture window resize
  // -----------------------------------------------------------------------
  
  function _resize() {
    // if the window has been resized then some positions need to be
    //  recalculated (especially those aligned to "right" or "top"
    var elements = _backgroundFixed.elements;
    for (var i in elements) _backgroundPosition(elements[i]);
    elements = _positionFixed.elements;
    for (i in elements) {
      _foregroundPosition(elements[i], true);
      // do this twice to be sure - hackish, I know :-)
      _foregroundPosition(elements[i], true);
    }
    _timer = 0;
  };
  
  // use a timer for some reason.
  //  (sometimes this is a good way to prevent resize loops)
  var _timer;
  addResize(function() {
    if (!_timer) _timer = setTimeout(_resize, 0);
  });
};
