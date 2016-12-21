$( function( ) {
  $( "input[name='valid_within_clade_q']" ).each( function( ) {
    var id = $( this ).parent( ).parent( ).find( "[data-ac-taxon-id]" );
    $( this ).taxonAutocomplete({
      searchExternal: false,
      bootstrapClear: false,
      thumbnail: false,
      idEl: id,
      initialSelection: $( this ).data( "initial-taxon" )
    });
  });
});
