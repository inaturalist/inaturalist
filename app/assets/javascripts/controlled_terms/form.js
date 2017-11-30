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

  function autocompleteForControlledTermTaxon( input ) {
    var id = $( input ).parents( ".nested-fields:first" ).find( "[name*=taxon_id]" );
    $( input ).taxonAutocomplete({
      searchExternal: false,
      bootstrapClear: false,
      idEl: id,
      initialSelection: $( input ).data( "initial-taxon" )
    });
  }
  $( "input.taxon-autocomplete" ).each( function ( ) {
    autocompleteForControlledTermTaxon( this );
  } );
  $( ".controlled_term_taxa" ).bind( "cocoon:after-insert", function( e, item ) {
    autocompleteForControlledTermTaxon( $( ":input:visible:first", item ) );
  })
});
