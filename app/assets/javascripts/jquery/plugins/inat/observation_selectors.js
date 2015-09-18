// This is a simple way to select observations in a form.
// Options:
//   baseURL:     Endpoint to query for observations.  Should accept query string as
//                a param called 'q'
//   urlParams:   Query param hash
//   autoLoad:    Whether or not to query with an empty string on page load. 
//                Default is true.
(function($){
  $.fn.observationSelector = function(options) {
    var options = $.extend({}, $.fn.observationSelector.defaults, options);
    
    // Setup each wrapper
    $(this).each(function() {
      setup(this, options);
    });
  };
  
  // Setup an individual observationSelector
  function setup(wrapper, options) {
    // Grab all the existing content
    var existing = $(wrapper).contents();
    
    // Insert a search field and button.  No forms, please
    var controls = $('<div class="observationSelectorControls"></div>').css(
      $.fn.observationSelector.defaults.controlsCSS
    );
    
    var input = $('<input type="text" class="text observationSelectorSearch"/>').css(
      $.extend($.fn.observationSelector.defaults.controlsCSS, {
        display: 'none' // until we get full-text search for observations
      })
    );
    if (typeof(options.defaultQuery) != 'undefined') {
      $(input).val(options.defaultQuery);
    };
    var button = $('<a href="#" class="button observationSelectorSearchButton">' + I18n.t('find_observations') + '</a>').css(
      $.extend($.fn.observationSelector.defaults.controlsCSS, {
        display: 'none' // until we get full-text search for observations
      })
    );
    
    // Append next & prev links
    var page = $('<input class="observationSelectorPage" type="hidden" value="1"/>');
    var prev = $('<a href="#" class="prevlink button">&laquo; ' + I18n.t('prev') + '</a>').click(function(e) {
      var pagenum = parseInt($(wrapper).find('.observationSelectorPage').val());
      pagenum -= 1;
      if (pagenum < 1) pagenum = 1;
      var prevOpts = $.extend({}, options);
      prevOpts.urlParams = $.extend({}, prevOpts.urlParams, {page: pagenum});
      $.fn.observationSelector.queryObservations(
        options.baseURL, 
        $(input).val(), 
        wrapper, 
        prevOpts);
      $(wrapper).find('.observationSelectorPage').val(pagenum);
      return false;
    });
    var next = $('<a href="#" class="nextlink button">' + I18n.t('next') + ' &raquo;</a>').click(function(e) {
      var pagenum = parseInt($(wrapper).find('.observationSelectorPage').val());
      pagenum += 1;
      var nextOpts = $.extend({}, options);
      nextOpts.urlParams = $.extend({}, nextOpts.urlParams, {page: pagenum});
      $.fn.observationSelector.queryObservations(
        options.baseURL, 
        $(input).val(), 
        wrapper, 
        nextOpts);
      $(wrapper).find('.observationSelectorPage').val(pagenum);
      return false;
    });
    var selectAll = $('<a href="#" class="selectall button">' + I18n.t('select_all') + '</a>').click(function(e) {
      $(wrapper).find('input:checkbox').prop('checked', true);
      return false;
    });
    var selectNone = $('<a href="#" class="selectnone button">' + I18n.t('select_none') + '</a>').click(function(e) {
      $(wrapper).find('input:checkbox').prop('checked', false);
      return false;
    });
    $(controls).append(input, button, page, prev, selectAll, selectNone, 
      next, $('<div></div>').css({
      height: 0, 
      visibility: 'hidden', 
      clear: 'both'})
    );
    $(wrapper).append(controls);
    
    // Insert a container to hold the observations
    var container = $('<div class="observationSelectorObservations"></div>').css(
      $.fn.observationSelector.defaults.containerCSS
    );
    $(wrapper).append(container);
    
    // Insert all existing content into the container
    $(container).append(existing);
    
    // Bind button clicks to search observations
    $(button).click(function(e) {
      $(wrapper).find('.observationSelectorPage').val(1);
      $.fn.observationSelector.queryObservations(options.baseURL, $(input).val(), wrapper, options);
      return false;
    });
    
    // Bind ENTER in search field to search observations
    $(input).keypress(function(e) {
      if (e.which == 13) {
        // Catch exceptions to ensure false return and precent form submission
        try {
          $(wrapper).find('.observationSelectorPage').val(1);
          $.fn.observationSelector.queryObservations(options.baseURL, $(input).val(), wrapper, options);
        }
        catch (e) {
          alert(e);
        }
        return false;
      };
    });
    
    // Fill with observations
    if (options.queryOnLoad) {
      $(document).ready(function() {
        var q = '';
        if (typeof(options.defaultQuery) == 'string') {
          q = options.defaultQuery;
        };
        $.fn.observationSelector.queryObservations(options.baseURL, q, wrapper, options);
      });
    };
  };
  
  // Hit the server for observations
  $.fn.observationSelector.queryObservations = function(baseURL, q, wrapper, options) {
    var options = options || {};
    var params = $.extend({}, options.urlParams, {'q': q});
    
    // Pull out parents of existing checked inputs
    var existing = $(wrapper).find(
      '.observationSelectorObservations input:checked').parents('.observation').clone();
    
    // Set loading status
    $(wrapper).find('.observationSelectorObservations').addClass('loading status').html(
      existing
    ).prepend('Loading...');
    
    // Fetch new fields
    $.get(  
      baseURL, 
      params, 
      function(responseText, textStatus, XMLHttpRequest) {
        $(wrapper).find('.observationSelectorObservations').html(responseText);
        // Remove fields with identical values to the extracted checkboxes
        var existingValues = $(existing).find('input').map(function() {
          return $(this).val();
        });
        $(this).find('input').each(function() {
          if ($.inArray($(this).val(), existingValues) != -1) {
            $(this).parents('.observation').remove();
          };
        });
        
        // Re-insert the checkbox parents
        $(wrapper).find('.observationSelectorObservations').prepend(existing)
        
        // Unset loading status
        $(wrapper).find('.observationSelectorObservations').removeClass('loading status');
        
        // Labelize new fields
        if (typeof($.fn.labelize) != 'undefined') {
          $('.observation', wrapper).labelize();
        };
      }
    );
    
    return false;
  };
  
  $.fn.observationSelector.defaults = {
    baseURL: '/observations/selector',
    queryOnLoad: true,
    formInputCSS: {
      float: 'left',
      'margin-top': 0
    },
    controlsCSS: {},
    containerCSS: {
      'background-position': 'top left'
    }
  };
})(jQuery);
