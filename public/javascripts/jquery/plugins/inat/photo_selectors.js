// This is a simple, perhaps even stupidly simple, way of selecting Flickr
// photos in a form.
// Options:
//   baseURL:       Endpoint to query for photos.  Should accept query string as
//                  a param called 'q'
//   urlParams:     Query param hash
//   queryOnLoad:   Whether or not to query with an empty string on page load. 
//                  Default is true.
//   defaultQuery:  Default query to run on load
//   afterQueryPhotos(q, wrapper, options) : called after photos queried
(function($){
  $.fn.photoSelector = function(options) {
    var options = $.extend({}, $.fn.photoSelector.defaults, options);
    
    // Setup each wrapper
    $(this).each(function() {
      setup(this, options);
    });
  };
  
  // Setup an individual photoSelector
  function setup(wrapper, options) {
    // Store the options
    $(wrapper).data('photoSelectorOptions', options)
    
    $(wrapper).addClass('photoSelector')
    
    // Grab all the existing content
    var existing = $(wrapper).contents();
    
    if (!options.noControls) { buildControls(wrapper, options) };
    
    // Insert a container to hold the photos
    var container = $('<div class="photoSelectorPhotos"></div>').css(
      $.fn.photoSelector.defaults.containerCSS
    );
    container.addClass('clear');
    $(wrapper).append(container);
    
    // Insert all existing content into the container
    $(container).append(existing);
    
    $(".facebookAlbums .album", wrapper).live('click', function() {
      $.fn.photoSelector.changeBaseUrl(wrapper, '/facebook/album/' + $(this).attr('data-aid'))
    })
    
    // Fill with photos
    if (options.queryOnLoad) {
      $(document).ready(function() {
        var q = '';
        if (typeof(options.defaultQuery) == 'string') {
          q = options.defaultQuery;
        };
        $.fn.photoSelector.queryPhotos(q, wrapper);
      });
    };
  };
  
  function buildControls(wrapper, options) {
    // Insert a search field and button.  No forms, please
    var controls = $('<div class="buttonrow photoSelectorControls"></div>').css(
      $.fn.photoSelector.defaults.controlsCSS
    );
    var input = $('<input type="text" class="text"/>').css(
      $.fn.photoSelector.defaults.formInputCSS
    );
    $(input).attr('id', 'photoSelectorSearchField');
    $(input).attr('name', 'photoSelectorSearchField');
    if (typeof(options.defaultQuery) != 'undefined') {
      $(input).val(options.defaultQuery);
    };
    var button = $('<a href="#" class="button findbutton">Find Photos</a>').css(
      $.fn.photoSelector.defaults.formInputCSS
    );
    
    var urlSelectWrapper = $('<span class="urlselect inter"><strong>Source:</strong> </span>');
    if (options.baseURL.match(/context=user/)) {
      var urlSelect = $('<select class="select" style="margin: 0 auto"></select>');
      var urls = options.urls || [];
      if (!options.skipLocal) {
        urls.push({
          title: "your hard drive",
          url: '/photos/local_photo_fields?context=user'
        })
      }
      $.each(urls, function() {
        if (this.url) {
          var title = this.title;
          var url = this.url;
        } else {
          var title = this;
          var url = this;
        }
        var option = $('<option value="'+url+'">'+title+'</option>');
        if (url === options.baseURL) $(option).attr('selected', 'selected');
        $(urlSelect).append(option);
      })
      
      $(urlSelect).change(function() {
        $.fn.photoSelector.changeBaseUrl(wrapper, $(this).val());
      })

      $('.back_to_albums').live('click', function(){
        $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val());
        return false;
      });

      $(urlSelectWrapper).append(urlSelect);
    }
    
    // Append next & prev links
    var page = $('<input class="photoSelectorPage" type="hidden" value="1"/>');
    var prev = $('<a href="#" class="prevlink button">&laquo; Prev</a>').click(function(e) {
      var pagenum = parseInt($(wrapper).find('.photoSelectorPage').val());
      pagenum -= 1;
      if (pagenum < 1) pagenum = 1;
      var prevOpts = $.extend({}, $(wrapper).data('photoSelectorOptions'));
      prevOpts.urlParams = $.extend({}, prevOpts.urlParams, {page: pagenum});
      $.fn.photoSelector.queryPhotos(
        $(input).val(), 
        wrapper, 
        prevOpts);
      $(wrapper).find('.photoSelectorPage').val(pagenum);
      return false;
    });
    var next = $('<a href="#" class="nextlink button">Next &raquo;</a>').click(function(e) {
      var pagenum = parseInt($(wrapper).find('.photoSelectorPage').val());
      pagenum += 1;
      var nextOpts = $.extend({}, $(wrapper).data('photoSelectorOptions'));
      nextOpts.urlParams = $.extend({}, nextOpts.urlParams, {page: pagenum});
      $.fn.photoSelector.queryPhotos(
        $(input).val(), 
        wrapper, 
        nextOpts);
      $(wrapper).find('.photoSelectorPage').val(pagenum);
      return false;
    });
    
    $(controls).append(input, button, page, prev, next);
    if (urlSelect) $(controls).append(urlSelectWrapper);
    $(controls).append($('<div></div>').css({
      height: 0, 
      visibility: 'hidden', 
      clear: 'both'})
    );
    
    $(wrapper).append(controls);
    
    if (options.baseURL.match(/local_photo/)) {
      $(wrapper).find('.photoSelectorControls .button, .photoSelectorControls .text').hide();
    }
    
    // Bind button clicks to search photos
    $(button).click(function(e) {
      $(wrapper).find('.photoSelectorPage').val(1);
      $.fn.photoSelector.queryPhotos($(input).val(), wrapper);
      return false;
    });
    
    // Bind ENTER in search field to search photos
    $(input).keypress(function(e) {
      if (e.which == 13) {
        // Catch exceptions to ensure false return and precent form submission
        try {
          $(wrapper).find('.photoSelectorPage').val(1);
          $.fn.photoSelector.queryPhotos($(input).val(), wrapper);
        }
        catch (e) {
          alert(e);
        }
        return false;
      };
    });
  }
  
  $.fn.photoSelector.changeBaseUrl = function(wrapper, url) {
    var options = $(wrapper).data('photoSelectorOptions');
    options.baseURL = url;
    $(wrapper).data('photoSelectorOptions', options);
    $.fn.photoSelector.queryPhotos($(wrapper).find('.photoSelectorSearchField').val(), wrapper);
  };
  
  // Hit the server for photos
  $.fn.photoSelector.queryPhotos = function(q, wrapper, options) {
    var options = $.extend({}, 
      $.fn.photoSelector.defaults, 
      $(wrapper).data('photoSelectorOptions'), 
      options
    );
    var params = $.extend({}, options.urlParams, {'q': q});
    var baseURL = options.baseURL;
    
    // Pull out parents of existing checked inputs
    var existing = $(wrapper).find('.photoSelectorPhotos input:checked').parent().clone();
    
    // Set loading status
    var loading = $('<center><span class="loading status inlineblock">Loading...</span></center>')
      .css('margin-top', $(wrapper).height() / 2)
    $(wrapper).shades('open', {
      css: {'background-color': 'white', 'opacity': 0.7}, 
      content: loading
    })
    
    // Fetch new fields
    $(wrapper).find('.photoSelectorPhotos').load(
      baseURL, 
      $.param(params),
      function(responseText, textStatus, XMLHttpRequest) {
        // Remove fields with identical values to the extracted checkboxes
        var existingValues = $(existing).find('input').map(function() {
          return $(this).val();
        });
        $(this).find('input').each(function() {
          if ($.inArray($(this).val(), existingValues) != -1) {
            $(this).parent().remove();
          };
        });
        
        // Re-insert the checkbox parents
        $(wrapper).find('.photoSelectorPhotos').prepend(existing)
        
        if (options.baseURL.match(/local_photo/)) {
          $(wrapper).find('.photoSelectorControls .button, .photoSelectorControls .text').hide();
          $(wrapper).find('.local_photos').show();
        } else {
          $(wrapper).find('.photoSelectorControls .button, .photoSelectorControls .text').show();
          $(wrapper).find('.local_photos').hide();
        }
        
        // Unset loading status
        $(wrapper).shades('close')
        
        if (typeof(options.afterQueryPhotos) == "function") options.afterQueryPhotos(q, wrapper, options);
      }
    );
    
    return false;
  };
  
  $.fn.photoSelector.defaults = {
    baseURL: '/flickr/photo_fields',
    queryOnLoad: true,
    formInputCSS: {
      float: 'left',
      'margin-top': 0
    },
    controlsCSS: {},
    containerCSS: {}
  };
})(jQuery);
