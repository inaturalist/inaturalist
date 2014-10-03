// Functions for manipulating checkboxes with jQuery

$.fn.check = function() {
  this.each(function() {
    this.checked = true;
  });
}
$.fn.uncheck = function() {
  this.each(function() {
    this.checked = false;
  });
}
$.fn.toggleCheck = function() {
  this.each(function() {
    if (this.checked) {
      this.checked = false;
    } else {
      this.checked = true;
    }
  });
}
