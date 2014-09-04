
// =========================================================================
// ie8-html.js
// =========================================================================

var UNSUCCESSFUL = /^(submit|reset|button)$/;

// -----------------------------------------------------------------------
// <button>
// -----------------------------------------------------------------------

// IE bug means that innerText is submitted instead of "value"
IE7.HTML.addRecalc("button,input", function(button) {
  if (button.tagName == "BUTTON") {
    var match = button.outerHTML.match(/ value="([^"]*)"/i);
    button.runtimeStyle.value = (match) ? match[1] : "";
  }
  // flag the button/input that was used to submit the form
  if (button.type == "submit") {
    addEventHandler(button, "onclick", function() {
      button.runtimeStyle.clicked = true;
      setTimeout("document.all." + button.uniqueID + ".runtimeStyle.clicked=false", 1);
    });
  }
});

// -----------------------------------------------------------------------
// <form>
// -----------------------------------------------------------------------

// only submit "successful controls
IE7.HTML.addRecalc("form", function(form) {
  addEventHandler(form, "onsubmit", function() {
    for (var element, i = 0; element = form[i]; i++) {
      if (UNSUCCESSFUL.test(element.type) && !element.disabled && !element.runtimeStyle.clicked) {
        element.disabled = true;
        setTimeout("document.all." + element.uniqueID + ".disabled=false", 1);
      } else if (element.tagName == "BUTTON" && element.type == "submit") {
        setTimeout("document.all." + element.uniqueID + ".value='" +
          element.value + "'", 1);
        element.value = element.runtimeStyle.value;
      }
    }
  });
});

// -----------------------------------------------------------------------
// <img>
// -----------------------------------------------------------------------

// get rid of the spurious tooltip produced by the alt attribute on images
IE7.HTML.addRecalc("img", function(img) {
  if (img.alt && !img.title) img.title = "";
});
