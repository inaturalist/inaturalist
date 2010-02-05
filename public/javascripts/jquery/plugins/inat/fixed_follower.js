// Enables Yelp-style following menu (or any div)
(function($){
  $.fn.fixedFollower = function(options) {
    var options = $.extend({}, $.fn.fixedFollower.defaults, options);
    
    // Make a closure and restyle the follower
    var follower = this;
    var originalOffset = follower.offset();
    var originalWidth = follower.width();
    $(follower).css({
      position: 'absolute',
      top: originalOffset.top,
      left: originalOffset.left,
      width: originalWidth
    });
    
    // Bind scrolling to move the follower
    $(window).scroll(function() {
      $(follower).stop(); // don't want tons of animations queuing up
      var destination = $(window).scrollTop() + options.top;
      if (destination < originalOffset.top) destination = originalOffset.top;
      $(follower).animate({
        top: destination
      }, options.duration, options.easing);
    });
  };
  
  $.fn.fixedFollower.defaults = {
    top: 20,
    duration: 1000,
    easing: 'swing'
  };
})(jQuery);
