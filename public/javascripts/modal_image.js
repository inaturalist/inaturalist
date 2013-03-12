$(document).ready(function() {
  $('#modal_image_box').jqm({
    closeClass: 'close', 
    ajax: '@data-photo-path',
    trigger: 'a.modal_image_link',
    onShow: function(h) {
      h.w.append($('<div class="loading status">Loading...</div>'));
      h.w.fadeIn(500);
      iNaturalist.modalCenter(h.w);
    },
    onLoad: function(h) {
      iNaturalist.modalCenter(h.w);
    },
    onHide: function(h) {
      h.w.fadeOut(500,function(){ h.o.remove(); })
    }
  });
});
