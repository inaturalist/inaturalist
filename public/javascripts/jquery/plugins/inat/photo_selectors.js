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
    var $searchInput = $('<input type="text" class="text" placeholder="Search" />').css(
      $.fn.photoSelector.defaults.formInputCSS
    );
    //$searchInput.attr('id', 'photoSelectorSearchField');
    $searchInput.attr('name', 'photoSelectorSearchField');
    if (typeof(options.defaultQuery) != 'undefined') {
      $searchInput.val(options.defaultQuery);
    };
    var $searchButton = $('<a href="#" class="button findbutton">Find Photos</a>').css(
      $.fn.photoSelector.defaults.formInputCSS
    );
    var $searchWrapper = $("<span style='display:none'></span>");
    $searchWrapper.append($searchInput).append($searchButton);
    
    var urlSelectWrapper = $('<span class="urlselect inter"><strong>Source:</strong> </span>');
    if (typeof options != 'undefined' && typeof options.urls != 'undefined') {
      var urlSelect = $('<select class="select" style="margin: 0 auto"></select>');
      urlSelect.change(function() {
        $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val());
      })
      var urls = options.urls || [];
      if (!options.skipLocal) {
        urls.push({
          title: "your hard drive",
          //url: '/photos/local_photo_fields?context=user'
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
      $(urlSelectWrapper).append(urlSelect);
    }

    if (typeof options != 'undefined' && typeof options.sources != 'undefined') {
      var sources = options.sources || {};
      var $allContextWrappers = [];
      if (!options.skipLocal) { sources['local'] = {title: "Your computer", url: '/photos/local_photo_fields'}; }
      var $sourceSelect = $("<select class='select'></select>");
      var sourceIndex = 0;
      $.each(sources, function(sourceKey, sourceData){
        var $sourceOption = $("<option value='"+sourceKey+"'>"+sourceData.title+"</option>");
        if (sourceData.url === options.baseUrl) { $sourceOption.attr('selected','selected') };
        $sourceSelect.append($sourceOption);
        var $contextWrapper = $("<span style='display:none'></span>");
        var $contextSelect = $("<select class='select'></select>");
        if (options.defaultSource) { // if we've specified a default source, and this it, show the associated contextSelect
          if (options.defaultSource != sourceKey) {
            $contextWrapper.css('display','inline-block');
          }
        } else if (sourceIndex==0) { // if we haven't specified a default source but this is the first one, show the associated contextSelect
          $contextWrapper.css('display','inline-block');
        }
        sourceIndex += 1;
        sourceData.contexts = (sourceData.contexts || []);
         // todo: 1 or 0 contexts
        $.each(sourceData.contexts, function(i,context){
          var $contextOption = $("<option value='"+context[1]+"'>"+context[0]+"</option>");
          if (context[2] && context[2].searchable) {
            $contextOption.data('searchable', true);
          }
          $contextSelect.append($contextOption);
        });
        $contextWrapper.append($contextSelect);
        //$contextWrapper.append(searchField());
        sources[sourceKey].$contextWrapper = $contextWrapper;
        $allContextWrappers.push($contextWrapper);
        $contextSelect.change(function(){ 
          updateSource(); 
        });
      });

      // todo: currentSource not defined at beginning
      var currentSource;
      function updateSource(sourceOptions){
        var newSource = sources[currentSource]; 
        sourceOptions = (sourceOptions || {});
        sourceOptions['url'] = (sourceOptions.url || newSource.url);
        sourceOptions['friend_uid'] = (sourceOptions.friend_uid || false);
        var currentContext;
        $searchWrapper.hide();
        if (typeof newSource.$contextWrapper == 'undefined') {
          sourceOptions['context'] = newSource.defaultContext;
        } else {
          sourceOptions['context'] = newSource.$contextWrapper.find('select').val();
          if (newSource.$contextWrapper.find("option:selected").data('searchable')) {
            // show search field
            $searchWrapper.show();
          } else {
        //    $searchWrapper.val('');
            $searchWrapper.hide();
          }
        }
        $.fn.photoSelector.changeBaseUrl(wrapper, sourceOptions['url'], sourceOptions['context'], sourceOptions['friend_uid']);
      }

      $sourceSelect.change(function(){
        var sourceKey = $(this).val();
        var sourceData = sources[sourceKey];
        // show the associated context <select>, and hide the others
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

      $(urlSelectWrapper).append($sourceSelect);
      $.each($allContextWrappers, function(i,c){
        $(urlSelectWrapper).append(c);
      });
      
    }

/*
    // photo context selector (user or friends)
    var contextSelect = $('<select class="select" style="margin: 0 auto"></select>');
    $.each([['Your photos', 'user'],['Your friends\' photos','friends']], function(){
      var selected = (this[1]==options.urlParams.context ? "selected='selected'" : '');
      contextSelect.append("<option value='"+this[1]+"'"+selected+">"+this[0]+"</option>");
    });
    
    // event handlers for urlSelect and contextSelect
    $.each([urlSelect,contextSelect], function(){
      this.change(function() {
        $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val(), contextSelect.val());
      })
    });

    if (options.urlParams == undefined || options.urlParams.context == undefined) {
      // hide the contextSelect 
      contextSelect.hide();
    }
*/

    $(".facebookAlbums .album", wrapper).live('click', function() {
      try {
      updateSource({
        url: '/facebook/album/'+$(this).data('aid'),
        friend_uid: $(this).closest('.facebookAlbums').data('friend_uid')
        });
      } catch(e) {
        console.log('catch!');
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          '/facebook/album/' + $(this).data('aid'), 
          'user', //contextSelect.val(), 
          $(this).closest('.facebookAlbums').data('friend_uid'));
      }
      return false;
    })
  
    $('.back_to_albums').live('click', function(){
      try {
        updateSource({ friend_uid: $(this).data('friend_uid') });
      } catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          urlSelect.val(), 
          'user', //contextSelect.val(), 
          $(this).data('friend_uid'));
      }
      return false;
    });

    $('.back_to_friends').live('click', function(){
      try {
        updateSource();
      } catch(e) {
        $.fn.photoSelector.changeBaseUrl(wrapper, urlSelect.val()); //, contextSelect.val());
      }
      return false;
    });

    // friend selector
    $('.friendSelector .friend').live('click', function(){
      try {
        updateSource({ friend_uid: $(this).data('friend_uid') });
      } catch(e) {
        $.fn.photoSelector.changeBaseUrl(
          wrapper, 
          urlSelect.val(), 
          'user', // contextSelect.val(), 
          $(this).data('friend_uid'));
      }
      return false;
    });

    
    // Append next & prev links
    var page = $('<input class="photoSelectorPage" type="hidden" value="1"/>');
    var prev = $('<a href="#" class="prevlink button">&laquo; Prev</a>').click(function(e) {
      var pagenum = parseInt($(wrapper).find('.photoSelectorPage').val());
      pagenum -= 1;
      if (pagenum < 1) pagenum = 1;
      var prevOpts = $.extend({}, $(wrapper).data('photoSelectorOptions'));
      prevOpts.urlParams = $.extend({}, prevOpts.urlParams, {page: pagenum});
      $.fn.photoSelector.queryPhotos(
        $searchInput.val(), 
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
        $searchInput.val(), 
        wrapper, 
        nextOpts);
      $(wrapper).find('.photoSelectorPage').val(pagenum);
      return false;
    });
    
    //if (urlSelect) $(controls).append(urlSelectWrapper);
    $(controls).append(urlSelectWrapper);
    //$(controls).append(input, button, page, prev, next);
    $(controls).append($searchWrapper, page, prev, next);
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
  
  $.fn.photoSelector.changeBaseUrl = function(wrapper, url, context, friend_id) {
    var options = $(wrapper).data('photoSelectorOptions');
    options.baseURL = url;
    options.urlParams.context = (context || 'user');
    options.urlParams.friend_id = (friend_id || null);
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
        if (existing && existing.length > 0) {
          //$(wrapper).find('.photoSelectorPhotos').prepend('<hr />').prepend(existing).prepend("<label>Selected photos</label><br />");
          $(wrapper).find('.photoSelectorPhotos').append('<hr />').append("<h4>Selected photos</h4>").append(existing);
        }
        
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
