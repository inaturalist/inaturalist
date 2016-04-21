$.fn.userAutocomplete = function( options ) {
  options = options || { };
  if( !options.idEl ) { return; }
  var field = this;

  field.template = function( item ) {
    var wrapperDiv = $( "<div/>" ).addClass( "ac" ).attr( "id", item.id );
    var labelDiv = $( "<div/>" ).addClass( "ac-label" );
    labelDiv.append( item.html );
    wrapperDiv.append( labelDiv );
    return wrapperDiv;
  };

  field.genericAutocomplete( _.extend( options, {
    extra_class: "user",
    source: function( request, response ) {
      $.ajax({
      url: "/people/search.json",
        dataType: "json",
        cache: true,
        data: {
          q: request.term,
          per_page: 10,
          order: "activity"
        },
        success: function( data ) {
          console.log(data);
          response( _.map( data, function( r ) {
            r.id = r.login;
            r.title = r.login;
            return r;
          }));
        }
      });
    }
  }));
};
