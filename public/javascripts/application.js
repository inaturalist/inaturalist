// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function num2letterID(num) {
    // Takes an positive integer and translates it into a unique letter ID.
    // Examples: 0 -> A, 25 -> Z, 26 -> AA, 27 -> AB, 51 -> AZ, 52 -> BA.
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    ID = alphabet[num % 26];
    return num <= 25 ? ID : alphabet[Math.floor(num/26)-1] + ID
}

function clickTip(obj, txt) {
  // Handles tip text in form elements when clicked
  if (obj.value == txt) obj.value=""; 
  obj.className = "formInput";
}

function blurTip(obj, txt) {
  // Handles tip text in form elements when blurred
  if (obj.value != "") return;
  obj.className = "formInputTip";
  obj.value = txt;
}

function toggleHeaderSubnav(link) {
  if ($(link).parents('.subnavtab').hasClass('open')) {
    closeHeaderSubnav(link);
  } else {
    openHeaderSubnav(link);
  }
}

function openHeaderSubnav(link) {
  $('.subnav').hide();
  $('.subnavtab').removeClass('open');
  $(link).parents('.subnavtab').addClass('open');
  $(link).parents('li').find('.subnav').show();
  $(document).click(subnavClickOff);
}

function closeHeaderSubnav(link) {
  $(link).parents('.subnavtab').removeClass('open');
  $(link).parents('li').find('.subnav').hide();
  $(document).unbind(subnavClickOff);
}

function subnavClickOff(e) {
  if ($(e.target).parents('.subnavwrapper').length == 0) {
    $('.subnav').hide();
    $('.subnavtab').removeClass('open');
  }
}
var QTIP_DEFAULTS = {
  hide: {
    fixed: true
  },
  style: {
    classes: 'ui-tooltip-light ui-tooltip-shadow',
    width: 'auto'
  },
  position: {
    viewport: $(window)
  }
}


$('a[data-loading-click], input[data-loading-click][type=radio], input[data-loading-click][type=checkbox]').live('click', function() {
  var txt = $(this).attr('data-loading-click')
  if ($.trim($(this).attr('data-loading-click')) == 'true') { txt = 'Loading...' }
  var loading = $('<div></div>').html(txt)
    .addClass('loadingclick inlineblock')
    .addClass($(this).attr('class'))
    .css('padding-left', '25px')
    .height($(this).height())
  if (txt == '') {
    loading.find('span').html(".").css('visibility', 'hidden').css('width', '0px')
  }
  $(this).hide().before(loading)
})

$('input[data-loading-click][type=text], input[data-loading-click][type=submit]').live('click', function() {
  var txt = $.trim($(this).attr('data-loading-click'))
  if ($.trim($(this).attr('data-loading-click')) == 'true') { txt = 'Saving...' }
  $(this).addClass('disabled description').val(txt)
  var link = this
  
  if (!$(this).attr('data-loading-click-bound')) {
    $(this).parents('form').bind('ajax:success', function() {
      $(link).attr('disabled', false).removeClass('disabled description')
    })
    $(this).attr('data-loading-click-bound', true)
  }
  
  $(this).parents('form').submit(function() {
    $(link).attr('disabled', true)
  })
})

$('[data-autosubmit]').live('change', function() {
  $(this).parents('form').submit()
})

function buildHelpTips() {
  var options = $.extend({}, QTIP_DEFAULTS, {
    show: {event: 'click'},
    hide: {event: 'unfocus'}
  })
  $('.helptip').each(function() {
    var content
    if ($(this).attr('rel').match(/^#/)) {
      content = $($(this).attr('rel')).html()
    } else {
      content = $(this).attr('rel')
    }
    
    var tipOptions = $.extend({}, options, {
      content: {
        text: content, 
        title: $(this).attr('data-helptip-title')
      }
    })
    if ($(this).attr('data-helptip-width')) {
      tipOptions.style = tipOptions.style || {}
      tipOptions.style.width = $(this).attr('data-helptip-width')
    }
    $(this).qtip(tipOptions)
  })
}

$(document).ready(function() {
  function makeHeaderLinkCurrent(li) {
    $(li).addClass('current').append(
      $('<img src="/images/active_tab_bottom.gif">').css({
        position: "absolute",
        left: '50%',
        bottom: '-6px',
        marginLeft: '-5px'
      })
    )
  }
  if (window.location.pathname.match(/^\/observations/)) {
    makeHeaderLinkCurrent('#mainnav .observationstab')
  } else if (window.location.pathname.match(/^\/taxa/)) {
    makeHeaderLinkCurrent('#mainnav .taxatab')
  } else if (window.location.pathname.match(/^\/projects/)) {
    makeHeaderLinkCurrent('#mainnav .projectstab')
  } else if (window.location.pathname.match(/^\/places/)) {
    makeHeaderLinkCurrent('#mainnav .placestab')
  } else if (window.location.pathname.match(/^\/user/) || window.location.pathname.match(/^\/people/)) {
    makeHeaderLinkCurrent('#mainnav .peopletab')
  }
  
  buildHelpTips()
  
  $('#usernav .signin_link, #usernav .signup_link').click(function() {
    if (window.location.pathname != '' && window.location.pathname != '/') {
      window.location = $(this).attr('href') + '?return_to=' + window.location
      return false
    }
  })
  
  $([
    '/images/spinner.gif',
    '/images/spinner-small.gif',
    '/images/spinner-small-ffffff_on_dedede.gif',
    '/images/spinner-small-ffffff_on_aaaaaa.gif'
  ]).preload()
  
  $('[data-tip]').each(autoTip)
  
  $('.source_nested_form_fields input.existing').chooser({
    collectionUrl: 'http://'+window.location.host + '/sources.json',
    resourceUrl: 'http://'+window.location.host + '/sources/{{id}}.json'
  })
})

function autoTip() {
  if ($(this).attr('data-tip').match(/^#/)) {
    content = $($(this).attr('data-tip')).html()
  } else {
    content = $(this).attr('data-tip')
  }
  var tipOptions = $.extend({}, QTIP_DEFAULTS)
  if ($(this).attr('data-tip-title')) {
    tipOptions.content = {
      text: content, 
      title: $(this).attr('data-helptip-title')
    }
  } else {
    tipOptions.content = content
  }
  
  if ($(this).attr('data-tip-show-delay')) {
    tipOptions.show = tipOptions.show || {}
    tipOptions.show.delay = parseInt($(this).attr('data-tip-show-delay'))
  }
  
  if ($(this).attr('data-tip-width')) {
    tipOptions.style = tipOptions.style || {}
    tipOptions.style.width = $(this).attr('data-tip-width')
  }
  
  if ($(this).attr('data-tip-style-classes')) {
    tipOptions.style = tipOptions.style || {}
    tipOptions.style.classes = $(this).attr('data-tip-style-classes')
  }
  
  if ($(this).attr('data-tip-position-at')) {
    tipOptions.position = tipOptions.position || {}
    tipOptions.position.at = $(this).attr('data-tip-position-at')
  }
  
  $(this).qtip(tipOptions)
}

// $(window).bind('load', function() {
//   $('.fluid.grid .taxon.img').each(function() {
//     // if ($(this).hasClass('noimg')) { return };
//     var img = $(this).find('.taxonimage img')
//     $(this).width(img.width())
//   })
// })

// from http://forum.jquery.com/topic/jquery-simple-autolink-and-highlight-12-1-2010
jQuery.fn.autolink = function() {
  return this.each(function() {
    var re = /((http|https|ftp):\/\/[\w?=&.\/-;#~%-]+(?![\w\s?&.\/;#~%"=-]*>))/g;
    $(this).html( $(this).html().replace(re, '<a href="$1">$1</a> ') );
  })
}

$.fn.preload = function() {
  this.each(function(){ $('<img/>')[0].src = this; })
}

$('.ui-widget-overlay, .shades').live('click', function() {
  $('.dialog:visible').dialog('close')
})

$.fn.shades = function(e, options) {
  options = options || {}
  elt = this[0]
  switch (e) {
    case 'close':
      $(elt).find('.shades:last').hide()
      break;
    case 'remove':
      $(elt).find('.shades:last').remove()
      break;
    default:
      var shades = $(elt).find('.shades:last')[0] || $('<div></div>')
      $(shades).addClass('shades')
      if (options.css) { $(shades).css(options.css) }
      if (options.content) { $(shades).html(options.content) }
      if (elt != document.body) {
        $(elt).css('position', 'relative')
        $(shades).css('position', 'absolute')
      }
      $(elt).append(shades)
      $(shades).show()
      break;
  }
}

$.fn.showInlineBlock = function() {
  $(this).css({
    'display': '-moz-inline-stack',
    'display': 'inline-block',
    'zoom': 1,
    '*display': 'inline'
  })
  return this
}
