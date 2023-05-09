/* eslint-disable */

// This is a most certainly stupidly simple way of selecting SoundCloud sounds, derived from the soundSelector plugin
// Options:
//   baseURL:       Endpoint to query for sounds.  Should accept query string as
//                  a param called 'q'
//   urlParams:     Query param hash
//   skipLocal:     Boolean, whether or not to skip local sound selection. Default is false
//   queryOnLoad:   Whether or not to query with an empty string on page load. 
//                  Default is true.
//   defaultQuery:  Default query to run on load
//   afterQuerySounds(q, wrapper, options) : called after sounds queried
//   defaultSource: the default source (e.g. 'flickr')
//   defaultContext:the default context (e.g. 'user' or 'friends')
//   sources:       a data structure used to specify the available sound sources (flickr, etc)
//                  and available sound contexts ('user', 'friends', 'public', etc) for each source
//                  see below for example of this data structure
//                  note: options also currently supports options.urls (via lots of try/catch), 
//                  but options.urls is deprecated in favor of options.sources
//  
//   example of options.sources:                  
//
//   options.sources = 
//      flickr: {
//        title: 'Flickr', 
//        url: '/flickr/sound_fields', 
//        contexts: [["Your sounds", 'user'], ["Your friends' sounds", 'friends'], ["Public sounds", 'public', {searchable:true}]]}
//    }
//
(function($){
  var MAX_FILE_SIZE = 20971520; // 20 MB in bytes

  $.fn.soundSelector = function(options) {
    var options = $.extend(true, {}, $.fn.soundSelector.defaults, options);
    
    // Setup each wrapper
    $(this).each(function() {
      setup(this, options);
    });
  };

  $.fn.soundSelector.bindMaxFileSizeValidation = function ( wrapper ) {
    $( ".sound_file_field input:file", wrapper ).not( ".max-file-sized" ).change( function( e ) {
      $( e.currentTarget ).addClass( "max-file-sized" );
      var files = e.currentTarget.files;
      for( var k in files ) {
        if ( files[k].size > MAX_FILE_SIZE) {
          alert( I18n.t( "uploader.errors.file_too_big", { megabytes: MAX_FILE_SIZE / 1024 / 1024 } ) );
          $( e.currentTarget ).val( null );
          break;
        }
      }
    } );
  }
  
  // Setup an individual soundSelector
  function setup(wrapper, options) {
    // Store the options
    $(wrapper).data('soundSelectorOptions', options)
    
    $(wrapper).addClass('soundSelector')
    
    // Grab all the existing content
    var existing = $(wrapper).contents();
    
    if (!options.noControls) { buildControls(wrapper, options) };
    
    // Insert a container to hold the sounds
    var container = $('<div class="soundSelectorSounds"></div>').css(
      $.fn.soundSelector.defaults.containerCSS
    );
    container.addClass('clear');
    $(wrapper).append(container);
    
    // Insert all existing content into the container
    $(container).append(existing);

    $.fn.soundSelector.bindMaxFileSizeValidation( wrapper );
    
    // Fill with sounds
    if (options.queryOnLoad) {
      $(document).ready(function() {
        $.fn.soundSelector.querySounds(wrapper, options)
      });
    };
  };
  
  function buildControls(wrapper, options) {
    var controls = $('<div class="buttonrow soundSelectorControls"></div>').css(
      $.fn.soundSelector.defaults.controlsCSS
    );

    // Append a source selector to match the photo selector
    var $sourceWrapper = $('<span class="urlselect inter"><strong>'+I18n.t('source')+':</strong> </span>');
    var sourceSelect = $('<select class="select" style="margin: 0 auto"></select>');
    sourceSelect.change(function() {
      $.fn.soundSelector.changeBaseUrl(wrapper, sourceSelect.val());
    });
    sourceSelect.append($('<option value="local">Your computer</option>'));
    sourceSelect.append($('<option value="soundcloud">SoundCloud</option>'));
    if ( options.baseURL.match( /soundcloud/ ) ) {
      sourceSelect.val( "soundcloud" );
    }
    $sourceWrapper.append(sourceSelect);
    controls.append($sourceWrapper);

    // Append next & prev links
    var offset = $('<input class="soundSelectorOffset" type="hidden" value="0"/>');
    var prev = $('<a href="#" class="prevlink button">&laquo; '+I18n.t('previous_page_short')+'</a>').click(function(e) {
      var offsetnum = parseInt($(wrapper).find('.soundSelectorOffset').val());
      offsetnum -= options.limit;
      if (offsetnum < 0) offsetnum = 0;
      var prevOpts = $.extend({}, $(wrapper).data('soundSelectorOptions'), {offset: offsetnum});
      $.fn.soundSelector.querySounds(
        wrapper, 
        prevOpts);
      $(wrapper).find('.soundSelectorOffset').val(offsetnum);
      return false;
    });
    var next = $('<a href="#" class="nextlink button">'+I18n.t('next_page_short')+' &raquo;</a>').click(function(e) {
      var offsetnum = parseInt($(wrapper).find('.soundSelectorOffset').val());
      offsetnum += options.limit;
      var nextOpts = $.extend({}, $(wrapper).data('soundSelectorOptions'), {offset: offsetnum});
      $.fn.soundSelector.querySounds(
        wrapper, 
        nextOpts);
      $(wrapper).find('.soundSelectorOffset').val(offsetnum);
      return false;
    });
    $(controls).append(offset, prev, next)
    $(controls).append($('<div></div>').css({
      height: 0, 
      visibility: 'hidden', 
      clear: 'both'})
    )
    
    $(wrapper).append(controls);
  }
  $.fn.soundSelector.changeBaseUrl = function(wrapper, source) {
    var options = $(wrapper).data('soundSelectorOptions');
    options.baseURL = "/sounds/local_sound_fields";
    if ( source === "soundcloud" ) {
      options.baseURL = "/soundcloud_sounds";
    }
    $(wrapper).data('soundSelectorOptions', options);
    $.fn.soundSelector.querySounds(wrapper, options);
  };


  // Hit the server for sounds
  $.fn.soundSelector.querySounds = function(wrapper, options) {
    // cancel any existing requests to avoid race condition
    var ajax = $(wrapper).data('ajax')
    if (typeof ajax != 'undefined') { ajax.abort(); }

    var options = $.extend({}, 
      $.fn.soundSelector.defaults, 
      $(wrapper).data('soundSelectorOptions'), 
      options
    )
    var params = {limit: options.limit, offset: options.offset, index: options.index}
    var baseURL = options.baseURL
    
    // Pull out parents of existing checked inputs
    if (!$(wrapper).data('soundSelectorExisting')) {
      $(wrapper).data('soundSelectorExisting', $(wrapper).find('.soundSelectorSounds input:checked').parent().clone())
    }
    
    // Set loading status
    var $soundSelectorSounds = $(wrapper).find('.soundSelectorSounds');
    var loading = $('<center><span class="loading status inlineblock">'+I18n.t('loading')+'...</span></center>')
      .css('margin-top', ($soundSelectorSounds.height() / 2)-20)
    $soundSelectorSounds.data('previous-overflow-x', $soundSelectorSounds.css('overflow-x'));
    $soundSelectorSounds.data('previous-overflow-y', $soundSelectorSounds.css('overflow-y'));
    $soundSelectorSounds.scrollTo(0,0)
    $soundSelectorSounds.css('overflow','hidden').shades('open', {
      css: {'background-color': 'white', 'opacity': 0.7}, 
      content: loading
    })
    
    // Fetch new fields
    ajax = $.ajax({
      url: baseURL, 
      data: $.param(params),
      success: function(response, textStatus, xhr) {
        $soundSelectorSounds.html(response);
        // Remove fields with identical values to the extracted checkboxes
        var existing = $(wrapper).data('soundSelectorExisting')
        var existingValues = $(existing).find('input').map(function() {
          return $(this).val()
        })
        $('input', $soundSelectorSounds).each(function() {
          if ($.inArray($(this).val(), existingValues) != -1) {
            $(this).parent().remove()
          }
        })
        
        // Re-insert the checkbox parents
        if (existing && existing.length > 0) {
          $soundSelectorSounds.children().wrapAll('<div class="soundSelectorResults"></div>')
          var selectedSoundsWrapper = $('<div class="soundSelectorSelected"></div>').html("<h4>"+I18n.t('sounds.selected_sounds')+"</h4>")
          selectedSoundsWrapper.append(existing)
          $soundSelectorSounds.prepend(selectedSoundsWrapper)
        }
        $(wrapper).data('soundSelectorExisting', null)

        $.fn.soundSelector.bindMaxFileSizeValidation( wrapper );
        
        // Unset loading status
        $soundSelectorSounds.shades('close')
        $soundSelectorSounds.css('overflow-x', $soundSelectorSounds.data('previous-overflow-x'));
        $soundSelectorSounds.css('overflow-y', $soundSelectorSounds.data('previous-overflow-y'));
        
        if (typeof(options.afterQuerySounds) == "function") options.afterQuerySounds(q, wrapper, options)
        return true
      }
    })
    $(wrapper).data('ajax', ajax)
    
    return false;
  };
  
  $.fn.soundSelector.defaults = {
    // baseURL: '/soundcloud_sounds',
    baseURL: "/sounds/local_sound_fields",
    limit: 20,
    offset: 0,
    index: 0,
    queryOnLoad: true,
    formInputCSS: {
      float: 'left',
      'margin-top': 0
    },
    controlsCSS: {},
    containerCSS: {}
  };
})(jQuery);
