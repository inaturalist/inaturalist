(function(){
/*
 * iNaturalist javascript library
 * Copyright (c) iNaturalist, 2007-2008
 * 
 * @date: 2008-01-01
 * @author: n8agrin
 * @author: kueda
 *
 * Much love to jQuery for the inspiration behind this class' layout.
 */
var iNaturalist = window.iNaturalist = new function(){
  
  // Abitlity to register distant namespases easily
  // based off of http://weblogs.asp.net/mschwarz/archive/2005/08/26/423699.aspx
  this.registerNameSpace = function(ns) {
   var nsParts = ns.split(".");
   var root = window;

   for(var i=0; i<nsParts.length; i++) {
    if(typeof root[nsParts[i]] == "undefined")
     root[nsParts[i]] = new Object();

    root = root[nsParts[i]];
   }
  };
  
  
  // Execute a RESTful delete by sending a DELETE request to a URL
  this.restfulDelete = function(deleteURL, options, target) {
    if(typeof(options.plural) == 'undefined') {
      var plural = false;
    } else {
      var plural = options.plural;
      options.plural = null;
    }
    var ajaxOptions = $.extend({}, options, {
      type: 'POST',
      data: $.extend({
        '_method': 'delete',
        'authenticity_token': $('meta[name=csrf-token]').attr('content')
      }, options.data),
      url: deleteURL
    });
    
    if (plural) {
      confirmStr = "Are you sure you want to delete these?";
    } else {
      confirmStr = "Are you sure you want to delete this?";
    };
    if (confirm(confirmStr)) {
      if (typeof(target) != 'undefined') {
        $(target).hide();
        var deleteStatus = $('<span class="loading status">Deleting...</span>');
        $(target).after(deleteStatus);
      };
      $.ajax(ajaxOptions);
    } else {
      return false;
    }
  };
  
  this.modalShow = function(o) {
    iNaturalist.modalCenter(o.w)
    o.w.show()
  }
  
  this.modalCenter = function(elt) {
    elt.height('auto')
    var height = $(window).height()*0.9
    if (elt.height() < height ) { height = elt.height() }
    if (height = elt.height()) {
      elt.height('auto')
    } else {
      elt.height(height)
    }
    var top = $(window).scrollTop() + $(window).height()/2 - elt.height()/2-20
    elt.css('top', top + 'px')
  }

}; // end of the iNaturalist singleton

// Class properties
iNaturalist.version = 0.1;

// Authenticity token placeholder, this allows valid post requests with
// Rails 2.x's new protect_from_forgery methods.  Unfortunately it must be
// set in the page since it is dependent on the user's specific session.
iNaturalist.form_authenticity_token = null;
})();
