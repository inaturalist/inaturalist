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
    name: 'green',
    tip: 'leftMiddle',
    border: {
      radius: 5
    },
    width: {
      max: 300
    }
  },
  position: {
    corner: {
      target: 'rightMiddle',
      tooltip: 'leftMiddle'
    },
    adjust: {'screen': true}
  }
}

$('a[data-loading-click]').live('click', function() {
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

$('input[data-loading-click]').live('click', function() {
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

function buildHelpTips() {
  var options = $.extend({}, QTIP_DEFAULTS, {
    show: {when: 'click'},
    hide: {when: 'unfocus'},
    position: {
      adjust: {'screen': true}
    }
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
      tipOptions.style.width = {
        min: $(this).attr('data-helptip-width')
      }
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
    '/images/spinner-small.gif',
    '/images/spinner-small-ffffff_on_dedede.gif',
    '/images/spinner-small-ffffff_on_aaaaaa.gif'
  ]).preload();
})

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

$('.ui-widget-overlay').live('click', function() {
  $('.dialog').dialog('close')
})
