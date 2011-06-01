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

QTIP_DEFAULTS = {
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
    adjust: {screen: true}
  }
}

$('a[data-loading-click]').live('click', function() {
  var txt = $.trim($(this).attr('data-loading-click'))
  if ($.trim($(this).attr('data-loading-click')) == 'true') { txt = 'Loading...' }
  var loading = $('<span></span>').html(txt).addClass('loading').addClass($(this).attr('class'))
  $(this).hide().before(loading)
})

$('input[data-loading-click]').live('click', function() {
  var txt = $.trim($(this).attr('data-loading-click'))
  if ($.trim($(this).attr('data-loading-click')) == 'true') { txt = 'Saving...' }
  $(this).addClass('disabled description').val(txt)
  var link = this
  $(this).parents('form').submit(function() {
    $(link).attr('disabled', true)
  })
})

function buildHelpTips() {
  var options = $.extend(QTIP_DEFAULTS, {
    show: {when: 'click'},
    hide: {when: 'unfocus'},
    position: {
      corner: {
        target: 'rightMiddle',
        tooltip: 'leftTop'
      }
    },
  })
  options.style.tip = 'leftTop'
  $('.helptip').each(function() {
    var content
    if ($(this).attr('rel').match(/^#/)) {
      content = $($(this).attr('rel')).html()
    } else {
      content = $(this).attr('rel')
    }
    $(this).qtip($.extend({}, options, {content: content}))
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
})
