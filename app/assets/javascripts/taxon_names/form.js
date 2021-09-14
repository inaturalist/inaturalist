$( "#place_taxon_names" ).bind( "cocoon:after-insert", function ( e, insertedItem ) {
  $( ".placechooser", insertedItem ).chooser( {
    collectionUrl: "/places/autocomplete.json",
    resourceUrl: "/places/{{id}}.json?partial=autocomplete_item"
  } );
} );

$( ".placechooser" ).chooser( {
  collectionUrl: "/places/autocomplete.json",
  resourceUrl: "/places/{{id}}.json?partial=autocomplete_item"
} );

$( "#taxon_name_lexicon" ).change( function ( e ) {
  console.log( "e: ", e.currentTarget.value );
  if ( e.currentTarget.value === "Scientific Names" ) {
    $( "#taxon_name_is_valid_sciname_prompt" ).removeClass( "hidden" );
    $( "#taxon_name_is_valid_comname_prompt" ).addClass( "hidden" );
  } else {
    $( "#taxon_name_is_valid_sciname_prompt" ).addClass( "hidden" );
    $( "#taxon_name_is_valid_comname_prompt" ).removeClass( "hidden" );
  }
} );
