/* eslint-disable */

// This is a simple, perhaps even stupidly simple, way of selecting Flickr
// photos in a form.
// Options:
//   baseURL:       Endpoint to query for photos.  Should accept query string as
//                  a param called 'q'
//   urlParams:     Query param hash
//   skipLocal:     Boolean, whether or not to skip local photo selection. Default is false
//   queryOnLoad:   Whether or not to query with an empty string on page load. 
//                  Default is true.
//   licensed:      Restrict iNat photos to those with licenses. Default is false.
//   defaultQuery:  Default query to run on load
//   afterQueryPhotos(q, wrapper, options) : called after photos queried
//   defaultSource: the default source (e.g. 'flickr')
//   defaultContext:the default context (e.g. 'user' or 'friends')
//   sources:       a data structure used to specify the available photo sources (flickr, etc)
//                  and available photo contexts ('user', 'friends', 'public', etc) for each source
//                  see below for example of this data structure
//                  note: options also currently supports options.urls (via lots of try/catch), 
//                  but options.urls is deprecated in favor of options.sources
//  
//   example of options.sources:                  
//
//   options.sources = {
//      flickr: {
//        title: 'Flickr', 
//        url: '/flickr/photo_fields', 
//        contexts: [["Your photos", 'user'], ["Your friends' photos", 'friends'], ["Public photos", 'public', {searchable:true}]]}
//    }
//
(function($){
  var MAX_FILE_SIZE = 20971520; // 20 MB in bytes

  function bindMaxFileSizeValidation( wrapper ) {
    $( ".photo_file_field input:file", wrapper ).not( ".max-file-sized" ).change( function( e ) {
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

  $.fn.photoSelector = function(options) {
    var options = $.extend(true, {}, $.fn.photoSelector.defaults, options);
    
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
    
    if ( !options.noControls) { buildControls(wrapper, options) };
    
    // Insert a container to hold the photos
    var container = $('<div class="photoSelectorPhotos"></div>').css(
      $.fn.photoSelector.defaults.containerCSS
    );
    container.addClass('clear');
    $(wrapper).append(container);
    
    // Insert all existing content into the container
    $(container).append(existing);

    bindMaxFileSizeValidation( wrapper );
    
    // Fill with photos
    if (options.queryOnLoad) {
      $(document).ready(function() {
        try {
          // yuk. ideally should just call updateSource, but can't cause of scope issues
          var defaultSourceData = options.sources[options.defaultSource];
          $.fn.photoSelector.changeBaseUrl(wrapper, defaultSourceData.url, options.defaultContext);
          if (typeof(options.defaultQuery) == 'string') {
            $.fn.photoSelector.queryPhotos(options.defaultQuery, wrapper)
          }
        } catch(e) {
          var q = '';
          if (typeof(options.defaultQuery) == 'string') {
            q = options.defaultQuery;
          };
          $( ".urlselect select", wrapper ).change( );
        }
      });
    };
  };
  
  function buildControls(wrapper, options) {
    if (options.bootstrap) {
      // Insert a search field and button.  No forms, please
      var controls = $('<div class="photoSelectorControls"></div>').css(
        $.fn.photoSelector.defaults.controlsCSS
      )
      var $searchInput = $('<input type="text" class="form-control" placeholder="'+I18n.t('search')+'" />')
      var $searchButton = $('<a href="#" class="btn btn-default findbutton">'+I18n.t('find_photos')+'</a>')
      var searchButtonWrapper = $('<span class="input-group-btn"></span>').html($searchButton)
      var $searchWrapper = $("<div class='photoSelectorSearch input-group'></div>")
      $searchWrapper.append($searchInput).append(searchButtonWrapper)
      var $sourceWrapper = $('<span class="urlselect inter"><strong>'+I18n.t('source')+':</strong> </span>')
    } else {
      // Insert a search field and button.  No forms, please
      var controls = $('<div class="buttonrow photoSelectorControls"></div>').css(
        $.fn.photoSelector.defaults.controlsCSS
      )
      var $searchInput = $('<input type="text" class="text" placeholder="'+I18n.t('search')+'" />').css(
        $.fn.photoSelector.defaults.formInputCSS
      )
      var $searchButton = $('<a href="#" class="button findbutton">'+I18n.t('find_photos')+'</a>').css(
        $.fn.photoSelector.defaults.formInputCSS
      )
      var $searchWrapper = $("<span class='photoSelectorSearch'></span>")
      $searchWrapper.append($searchInput).append($searchButton)
      var $sourceWrapper = $('<span class="urlselect inter"><strong>'+I18n.t('source')+':</strong> </span>')
    }

    $searchInput.attr('name', 'photoSelectorSearchField')
    if (typeof(options.defaultQuery) != 'undefined') {
      $searchInput.val(options.defaultQuery)
    }

    // this branch is for backwards compatibility 
    // options.urls is used by legacy photoSelectors, but is now deprecated. 
    // use options.sources (see below) instead.
    if (typeof options != 'undefined' && typeof options.urls != 'undefined') {
      var urlSelect = $('<select class="select" style="margin: 0 auto"></select>');
      urlSelect.change(function() {
        $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val());
      })
      var urls = options.urls || [];
      if (!options.skipLocal) {
        urls.push({
          title:  I18n.t('your_hard_drive'),
          url: '/photos/local_photo_fields'
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
      $sourceWrapper.append(urlSelect);
    }

    // this branch is for options.sources (new style of photoselector)
    if (typeof options != 'undefined' && typeof options.sources != 'undefined') {

      // this is called when you change either the source <select> or context <select>
      function updateSource(sourceOptions){
        $searchWrapper.hide()
        $searchInput.val('')
        var newSource = sources[currentSource]
        sourceOptions = sourceOptions || {}
        sourceOptions['url'] = sourceOptions.url || newSource.url
        sourceOptions['object_id'] = sourceOptions.object_id || false
        if (typeof newSource.$contextWrapper == 'undefined') {
          // TODO: this is what happens when there isn't a $contextSelect for this source (i.e. only one available context)
          //sourceOptions['context'] = newSource.defaultContext;
        } else {
          var currentContextName = newSource.$contextWrapper.find('select').val()
          sourceOptions['context'] = currentContextName
          for (var i = 0; i < newSource.contexts.length; i++) {
            var currentContext = newSource.contexts[i]
            if (newSource.contexts[i][0] == currentContextName) break
          }
          if (currentContext && currentContext[currentContext.length-1].searchable) {
            // show search field
            $searchWrapper.show();
          } else {
            $searchWrapper.hide();
          }
        }
        $.fn.photoSelector.changeBaseUrl(wrapper, sourceOptions['url'], sourceOptions['context'], sourceOptions['object_id']);
      }

      $searchWrapper.hide();
      var sources = options.sources || {};
      var currentSource = options.defaultSource;
      var $allContextWrappers = [];
      if (!options.skipLocal) { sources['local'] = {title: "Your computer", url: '/photos/local_photo_fields'}; }
      var $sourceSelect = $("<select class='select'></select>");
      var sourceIndex = 0; // used as index when iterating over sources below
      $.each(sources, function(sourceKey, sourceData){
        var $sourceOption = $("<option value='"+sourceKey+"'>"+sourceData.title+"</option>");
        $sourceSelect.append($sourceOption);
        var $contextWrapper = $("<span style='display:none'></span>");
        if (typeof options.defaultSource != 'undefined') { 
          if (options.defaultSource == sourceKey) { // if we've specified a default source, and this it, show the associated contextSelect
            $contextWrapper.css('display','inline-block');
            $sourceOption.attr('selected','selected');
            currentSource = sourceKey; 
          } 
        } else if (sourceIndex==0) { // if we haven't specified a default source but this is the first one, show the associated contextSelect
          currentSource = sourceKey; 
          $contextWrapper.css('display','inline-block');
        }
        sourceIndex += 1;
        sourceData.contexts = (sourceData.contexts || []);
        // create a sub-<select> menu for contexts, but only if this photo source has more than one possible context
        if (sourceData.contexts.length > 1) {
          var $contextSelect = $("<select class='select'></select>").change(updateSource);
          $.each(sourceData.contexts, function(i,context){
            var $contextOption = $("<option value='"+context[1]+"'>"+context[0]+"</option>");
            // if searchable=true in context options, search box will be visible when this context is selected
            // for example, if context is flickr public photos, we want to show the search box
            // e.g. ["Public photos", "public", {searchable:true}]
            var searchable = (context[2] && context[2].searchable);
            if (searchable) { $contextOption.data('searchable', true); } 
            if ((typeof options.defaultContext != 'undefined') && (options.defaultContext==context[1])) { // default context
              $contextOption.attr('selected','selected');
              if (searchable) { $searchWrapper.show() }
            }
            $contextSelect.append($contextOption);
          });
          $contextWrapper.append($contextSelect);
        } else if (sourceData.contexts.length == 1) {
          var context = sourceData.contexts[0],
              searchable = (context[2] && context[2].searchable)
          if (searchable) { $searchWrapper.show() }
        }
        sources[sourceKey].$contextWrapper = $contextWrapper;
        $allContextWrappers.push($contextWrapper);
      });


      $sourceSelect.change(function(){
        var sourceKey = $sourceSelect.val();
        var sourceData = sources[sourceKey];
        // show the associated context <select>, and hide all the other context <selects>
        $.each($allContextWrappers, function(i,c) { 
          if (sourceData.$contextWrapper && (sourceData.$contextWrapper==c)) {
            c.show();
          } else {
            c.hide(); 
          }
        });
        currentSource = sourceKey;
        updateSource();
      });

      $sourceWrapper.append($sourceSelect);
      $.each($allContextWrappers, function(i,c){ $sourceWrapper.append(c); });

    }

    $(wrapper).on('click', ".picasaAlbums .album", function() {
      var aid = $(this).attr('data-aid'); // $(this).data('aid') doesn't work because of ridiculous type conversion
      try {
        updateSource({
          url: '/picasa/album/'+aid,
          object_id: $(this).closest('.picasaAlbums').attr('data-friend_id')
          });
      } catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          '/picasa/album/' + aid, 
          'user', //contextSelect.val(), 
          $(this).closest('.picasaAlbums').attr('data-friend_id'));
      }
      return false;
    });
  
    $(wrapper).on('click', '.back_to_albums', function(){
      try { updateSource({ object_id: $(this).attr('data-friend_id') }); } 
      catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          urlSelect.val(), 
          'user', //contextSelect.val(), 
          $(this).attr('data-friend_id'));
      }
      return false;
    });

    $(wrapper).on('click', '.back_to_friends', function(){
      try { updateSource(); } 
      catch(e) { $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val()); }
      return false;
    });

    $(wrapper).on('click', '.back_to_groups', function(){
      try { updateSource({ object_id: $(this).attr('data-group_id') }); } 
      catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          urlSelect.val(), 
          'groups', //contextSelect.val(), 
          $(this).attr('data-group_id'));
      }
      return false;
    });

    // friend selector
    $(wrapper).on('click', '.friendSelector .friend', function(){
      try { updateSource({ object_id: $(this).attr('data-friend_id') }); } 
      catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          urlSelect.val(), 
          'user', // contextSelect.val(), 
          $(this).attr('data-friend_id'));
      }
      return false;
    });

    
    // Append next & prev links
    var page = $('<input class="photoSelectorPage" type="hidden" value="1"/>')
    if (options.bootstrap) {
      var prev = $('<button type="button" class="prevlink btn btn-default">&laquo; '+I18n.t('previous_page_short')+'</button>')
      var next = $('<button type="button" class="nextlink btn btn-default">'+I18n.t('next_page_short')+' &raquo;</button>')
    } else {
      var prev = $('<a href="#" class="prevlink button">&laquo; '+I18n.t('previous_page_short')+'</a>')
      var next = $('<a href="#" class="nextlink button">'+I18n.t('next_page_short')+' &raquo;</a>')
    }
    prev.click(function(e) {
      var prevOpts = $.extend({}, $(wrapper).data('photoSelectorOptions'));
      var currentURL = $( ".urlselect select", wrapper ).val( );
      if ( currentURL && currentURL.match( /picasa/ ) ) {
        return false;
      }
      var pagenum = parseInt( $( wrapper ).find( ".photoSelectorPage" ).val( ) );
      pagenum -= 1;
      if ( pagenum < 1 ) pagenum = 1;
      prevOpts.urlParams = $.extend( {}, prevOpts.urlParams, { page: pagenum } );
      $(wrapper).find('.photoSelectorPage').val(pagenum);
      $.fn.photoSelector.queryPhotos(
        $searchInput.val(), 
        wrapper, 
        prevOpts);
      return false;
    })
    next.click(function(e) {
      var nextOpts = $.extend({}, $(wrapper).data('photoSelectorOptions'));
      var currentURL = $( ".urlselect select", wrapper ).val( );
      if ( currentURL && currentURL.match( /picasa/ ) ) {
        var nextPageToken = $( "[name='next_page_token']", wrapper ).val( );
        if ( nextPageToken ) {
          nextOpts.urlParams = $.extend({}, nextOpts.urlParams, { page_token: nextPageToken } );
          $(wrapper).find('.photoSelectorPageToken').val( nextPageToken );
          $(wrapper).find('.photoSelectorNextPageToken').val( null );
        } else {
          return false;
        }
      } else {
        var pagenum = parseInt($(wrapper).find('.photoSelectorPage').val());
        pagenum += 1;
        nextOpts.urlParams = $.extend({}, nextOpts.urlParams, {page: pagenum});
        $(wrapper).find('.photoSelectorPage').val(pagenum);
      }
      $.fn.photoSelector.queryPhotos(
        $searchInput.val(), 
        wrapper, 
        nextOpts);
      return false;
    })

    if (options.bootstrap) {
      var allNoneLabel = $('<label>'+I18n.t('select')+'</label>')
      var selectAll = $('<button type="button" class="btn btn-default">'+I18n.t('all')+'</button>')
      var selectNone = $('<button type="button" class="btn btn-default">'+I18n.t('none')+'</button>')
    } else {
      var allNoneLabel = $('<label class="inter">'+I18n.t('select')+'</label>')
      var selectAll = $('<a href="#" class="inter">'+I18n.t('all')+'</a>')
      var selectNone = $('<a href="#" class="inter">'+I18n.t('none')+'</a>')
    }
    selectAll.click(function() {
      $('.photoSelectorPhotos input:checkbox', wrapper).not('.photoSelectorSelected input').prop('checked', true)
      return false
    })
    selectNone.click(function() {
      $('.photoSelectorPhotos input:checkbox', wrapper).not('.photoSelectorSelected input').prop('checked', false)
      return false
    })
    
    $(controls).append($sourceWrapper)
    if ($sourceWrapper.find('select').length == 0) { 
      $sourceWrapper.hide()
    }
    if (options.bootstrap) {
      var prevnext = $('<div class="btn-group"></div>')
      prevnext.append(prev,next)
      var allNone = $('<div class="allNone form-inline"></div>'),
          allNoneButtons = $('<div class="btn-group"></div>')
      allNoneLabel.addClass('checkbox')
      allNoneButtons.append(selectAll, selectNone)
      allNone.append(allNoneLabel, allNoneButtons)
      prevnext.addClass('pull-right')
      allNone.addClass('pull-right')

      controls.addClass('row stacked')
      controls.append($('<div class="col-xs-6"></div>').append($searchWrapper))
      controls.append($('<div class="col-xs-6"></div>').append(prevnext, allNone))
      controls.append(page);
    } else {
      var allNone = $('<span class="allNone nobr inlineblock buttoncontainer"></span>')
      allNone.append(allNoneLabel, selectAll, selectNone)
      $(controls).append($searchWrapper, page, prev, next, allNone);
    }
    $(controls).append($('<div></div>').css({
      height: 0, 
      visibility: 'hidden', 
      clear: 'both'})
    )
    
    $(wrapper).append(controls);
    
    if (options.baseURL && options.baseURL.match(/local_photo/) && $sourceWrapper.find('select').length != 0) {
      $('.nextlink, .prevlink, .allNone, .photoSelectorSearch', wrapper).hide()
      $sourceWrapper.show()
    }
    
    // Bind button clicks to search photos
    $searchButton.click(function(e) {
      $(wrapper).find('.photoSelectorPage').val(1);
      $.fn.photoSelector.queryPhotos($searchInput.val(), wrapper);
      return false;
    });
    
    // Bind ENTER in search field to search photos
    $searchInput.keypress(function(e) {
      if (e.which == 13) {
        // Catch exceptions to ensure false return and precent form submission
        try {
          $(wrapper).find('.photoSelectorPage').val(1);
          $.fn.photoSelector.queryPhotos($searchInput.val(), wrapper);
        }
        catch (e) {
          alert(e);
        }
        return false;
      };
    });
  }
  
  $.fn.photoSelector.changeBaseUrl = function(wrapper, url, context, object_id) {
    var options = $(wrapper).data('photoSelectorOptions');
    options.baseURL = url;
    options.urlParams.context = (context || 'user');
    options.urlParams.object_id = (object_id || null);
    $(wrapper).data('photoSelectorOptions', options);
    if ( url && url.match( /picasa/ ) ) {
      $( ".photoSelectorSearch", wrapper ).hide( );
      $( ".prevlink", wrapper ).hide( );
    } else {
      $( ".photoSelectorSearch", wrapper ).show( );
      $( ".prevlink", wrapper ).show( );
    }
    $.fn.photoSelector.queryPhotos($(wrapper).find('.photoSelectorSearchField').val(), wrapper);
  };

  // Hit the server for photos
  $.fn.photoSelector.queryPhotos = function(q, wrapper, options) {
    // cancel any existing requests to avoid race condition
    var ajax = $(wrapper).data('ajax')
    if (typeof ajax != 'undefined') { ajax.abort(); }

    var options = $.extend({}, 
      $.fn.photoSelector.defaults, 
      $(wrapper).data('photoSelectorOptions'), 
      options
    )
    var params = $.extend({}, options.urlParams, {'q': q})
    var baseURL = options.baseURL

    params.licensed = options.licensed
    
    // Pull out parents of existing checked inputs
    if (!$(wrapper).data('photoSelectorExisting')) {
      $(wrapper).data('photoSelectorExisting', $(wrapper).find('.photoSelectorPhotos input:checked').parent().clone())
    }
    
    // Set loading status
    var $photoSelectorPhotos = $(wrapper).find('.photoSelectorPhotos');
    if ($photoSelectorPhotos.data('previous-overflow-x') != 'hidden') {
      $photoSelectorPhotos.data('previous-overflow-x', $photoSelectorPhotos.css('overflow-x'))
    }
    if ($photoSelectorPhotos.data('previous-overflow-y') != 'hidden') {
      $photoSelectorPhotos.data('previous-overflow-y', $photoSelectorPhotos.css('overflow-y'))
    }
    $photoSelectorPhotos.scrollTo(0,0)
    $photoSelectorPhotos.css('overflow','hidden')
    $photoSelectorPhotos.loadingShades(I18n.t('loading'), {
      cssClass: 'smallLoading centered',
      top: '20px'
    })
    
    // Fetch new fields
    ajax = $.ajax({
      url: baseURL, 
      data: $.param(params),
      success: function(response, textStatus, xhr) {
        $photoSelectorPhotos.html(response);
        // Remove fields with identical values to the extracted checkboxes
        var existing = $(wrapper).data('photoSelectorExisting')
        var existingValues = $(existing).find('input').map(function() {
          return $(this).val()
        })
        $('input', $photoSelectorPhotos).each(function() {
          if ($.inArray($(this).val(), existingValues) != -1) {
            $(this).parent().remove()
          }
        })
        
        // Re-insert the checkbox parents
        if (existing && existing.length > 0) {
          $photoSelectorPhotos.children().wrapAll('<div class="photoSelectorResults"></div>')
          var selectedPhotosWrapper = $('<div class="photoSelectorSelected"></div>'),
              header = "<h4>"+I18n.t('selected_photos')+"</h4>"
          if (options.bootstrap) {
            var row = $('<div class="row"></div>')
            row.append(existing)
            selectedPhotosWrapper.append(header, row)
          } else {
            selectedPhotosWrapper.append(header, existing)
          }
          $photoSelectorPhotos.prepend(selectedPhotosWrapper)
        }
        $(wrapper).data('photoSelectorExisting', null)
        
        if (options.baseURL && options.baseURL.match(/local_photo/)) {
          $('.nextlink, .prevlink, .allNone, .photoSelectorSearch', wrapper).hide()
          $(wrapper).find('.local_photos').show()
          // Prevent adding files that are too big
          bindMaxFileSizeValidation( wrapper );
        } else {
          if ( options.baseURL && options.baseURL.match( /picasa/ ) ) {
            $('.nextlink, .allNone, .photoSelectorSearch', wrapper).show( );
            $( ".photoSelectorSearch input" ).hide( );
          } else {
            $('.nextlink, .prevlink, .allNone, .photoSelectorSearch', wrapper).show()
          }
          $(wrapper).find('.local_photos').hide()
        }

        // remove multiple file inputs for Windows Safari
        if (navigator.platform.match(/^Win/) && $.browser.webkit && !navigator.userAgent.match(/Chrome/i)) {
          $('input[type=file]', wrapper).removeAttr("multiple")
        }
        
        // Unset loading status
        $photoSelectorPhotos.shades('close')
        if ($photoSelectorPhotos.data('previous-overflow-x') != 'hidden') {
          $photoSelectorPhotos.css('overflow-x', $photoSelectorPhotos.data('previous-overflow-x'))
        }
        if ($photoSelectorPhotos.data('previous-overflow-y') != 'hidden') {
          $photoSelectorPhotos.css('overflow-y', $photoSelectorPhotos.data('previous-overflow-y'))
        }
        
        if (typeof(options.afterQueryPhotos) == "function") options.afterQueryPhotos(q, wrapper, options)
        return true
      },
      complete: function() {
        if ($photoSelectorPhotos.data('previous-overflow-x') != 'hidden') {
          $photoSelectorPhotos.css('overflow-x', $photoSelectorPhotos.data('previous-overflow-x'))
        }
        if ($photoSelectorPhotos.data('previous-overflow-y') != 'hidden') {
          $photoSelectorPhotos.css('overflow-y', $photoSelectorPhotos.data('previous-overflow-y'))
        }
      }
    })
    $(wrapper).data('ajax', ajax)
    
    return false;
  };
  
  $.fn.photoSelector.defaults = {
    baseURL: '/photos/local_photo_fields',
    queryOnLoad: true,
    defaultSource: 'local',
    formInputCSS: {
      float: 'left',
      'margin-top': 0
    },
    controlsCSS: {},
    containerCSS: {}
  };
})(jQuery);
