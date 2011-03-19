// This is a VERY light wrapper around the JQueryUI datepicker plugin for use
// in iNat.
(function($){
  // Override datepicker's keybaord nav.  It makes baby jesus cry.
  $.datepicker._doKeyPress = function(e) {
    return true;
  }
  
  $.fn.iNatDatepicker = function(args) {
    $(this).width($(this).width() - 26);
    $(this).css({
      'margin-right': '10px',
      'vertical-align': 'middle'
    });
    $(this).datepicker({
      showOn: 'both',
      buttonImage: "/images/silk/date.png",
      buttonImageOnly: true,
      showButtonPanel: true,
      showAnim: 'fadeIn',
      maxDate: '+0d',
      constrainInput: false,
      firstDay: 0,
      changeFirstDay: false,
      changeMonth: true,
      changeYear: true,
      dateFormat: 'yy-mm-dd'
    });
    $(this).next('.ui-datepicker-trigger').css({
      'vertical-align': 'middle'
    });
  };
})(jQuery);
