/* global I18n */
/* global SCIENTIFIC_NAMES_LEXICON */

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

$( function ( ) {
  $( ".btn.delete" ).click( function ( e ) {
    e.preventDefault( );
    e.stopPropagation( );
    // eslint-disable-next-line no-alert
    if ( window.confirm( I18n.t( "are_you_sure_want_delete_this_name" ) ) === true ) {
      $( "input[name=\"_method\"]" ).val( "delete" );
      $( "form.edit_taxon_name" ).submit( );
    }
  } );

  $( "#taxon_name_lexicon" ).change( function ( ) {
    var lexicon = $( "#taxon_name_lexicon" ).val( );
    if ( lexicon === SCIENTIFIC_NAMES_LEXICON ) {
      $( "#is_valid_scientific_name_label" ).attr( "hidden", false );
      $( "#is_valid_common_name_label" ).attr( "hidden", true );
    } else {
      $( "#is_valid_common_name_label" ).attr( "hidden", false );
      $( "#is_valid_scientific_name_label" ).attr( "hidden", true );
    }
  } );
} );
