(function($){
  $.fn.placeAutocomplete = function(url, options) {
    var options = $.extend({}, options);
    this.each(function() {
      setup(this, url, options);
    });
  }
  
  // Setup a single taxon selector
  function setup(input, url, options) {
    var options = $.extend({}, options);
    var choosePlaceOptions = {};
    var clearPlaceOptions = {};
    if (typeof(options.afterChoosePlace) == 'function') choosePlaceOptions.after = options.afterChoosePlace;
    if (typeof(options.afterClearPlace) == 'function') clearPlaceOptions.after = options.afterClearPlace;
    var autocompleteOptions = $.extend({
      formatItem: function(data, i, total) {
        var placeJSON = eval('(' + data[0] + ')');
        return $.fn.placeAutocomplete.formattedAutocompletePlace(placeJSON);
      },
      formatResult: function(data, i, total) {
        var placeJSON = eval('(' + data[0] + ')');
        return placeJSON.name;
      }
    }, options.autocompleteOptions || {});
    var url = typeof(url) == 'undefined' ? '/places/autocomplete' : url;
    
    // Add the status
    var status = $('<div class="placeAutocompleteStatus success status"></div>').append(
      $('<a class="placeAutocompleteClear href="#">clear</a>').click(function() {
        $.fn.placeAutocomplete.clearPlace(input, clearPlaceOptions)
      }),
      $('<span class="placeAutocompletePlaceWrapper"></span>')
    );
    $(input).after(status);
    $(status).hide();
    
    // Store ID field and status as data
    if (typeof(options.placeIdField) == 'undefined') {
      var placeIdField = $(input).parents('form').find('input[name="place_id"]:first');
      if (placeIdField.length == 0) {
        placeIdField = $(input).parents('form').find('input[name*="[place_id]"]:first');
      }
    } else {
      var placeIdField = options.placeIdField
    }
    $(input).data('placeIdField', placeIdField);
    $(input).data('statusField', status);
    
    // Setup the autocompleter
    $(input).autocomplete(url, autocompleteOptions).result(function(event, data, formatted) {
      var placeJSON = eval('(' + data[0] + ')')
      $.fn.placeAutocomplete.choosePlace(input, placeJSON, choosePlaceOptions)
      return false
    })
    
    // Set existing
    if ($(placeIdField).val() && $(input).attr('data-json')) {
      var placeJSON = eval('(' + $(input).attr('data-json') + ')')
      $.fn.placeAutocomplete.choosePlace(input, placeJSON, choosePlaceOptions)
    } else {
      $(input).change(function() {
        if ($.trim($(this).val()) == '') {
          $(placeIdField).val('')
        }
      })
    }
    
    // Prevent ENTER
    $(input).keypress(function(e) {
      if (e.which == 13) return false
    })
  }
  
  $.fn.placeAutocomplete.formattedAutocompletePlace = function(placeJSON) {
    var html = placeJSON.display_name
    if (placeJSON.place_type_name) {
      html += ' <span class="description">' + placeJSON.place_type_name + '</span>'
    }
    return html
  }
  
  $.fn.placeAutocomplete.choosePlace = function(input, placeJSON, options) {
    var options = $.extend({}, options);
    var idfield = $(input).data('placeIdField');
    var status = $(input).data('statusField');
    
    $(idfield).val(placeJSON.id);
    $(status).find('.placeAutocompletePlaceWrapper:first').html(
      $.fn.placeAutocomplete.formattedAutocompletePlace(placeJSON));
    $(status).show();
    $(input).hide();
    
    if (typeof(options.after) == 'function') {
      options.after(input, placeJSON);
    };
  }
  
  $.fn.placeAutocomplete.clearPlace = function(input, options) {
    var options = $.extend({}, options);
    var idfield = $(input).data('placeIdField');
    var status = $(input).data('statusField');
    
    $(status).hide();
    $(input).val('').show();
    $(idfield).val('');
    
    if (typeof(options.after) == 'function') {
      options.after(input);
    };
  }
})(jQuery);
