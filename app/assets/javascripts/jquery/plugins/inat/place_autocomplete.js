$.fn.placeAutocomplete = function( options ) {
  options = options || { };
  if( !options.id_el ) { return; }
  var field = this;
  field.genericAutocomplete( _.extend( options, {
    source: function( request, response ) {
      $.ajax({
        url: "/places/autocomplete.json",
        dataType: "jsonp",
        data: {
          term: request.term,
          per_page: 10
        },
        success: function( data ) {
          response( _.map( data, function( r ) {
            r.title = r.display_name;
            return r;
          }));
        }
      });
    },
    select: function( e, ui ) {
      // show the title in the text field
      if( ui.item.id ) {
        field.val( ui.item.title );
      }
      // set the hidden id field
      options.id_el.val( ui.item.id );
      if( options.afterSelect ) { options.afterSelect( ui ); }
      e.preventDefault( );
      return false;
    }
  }));
};
