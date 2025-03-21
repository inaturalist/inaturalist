$( function ( ) {
  $( "form #user_name" ).userAutocomplete( { idEl: $( "#user_id" ) } );
  $( "form #flagger_name" ).userAutocomplete( { idEl: $( "#flagger_user_id" ) } );
  $( "form #flagger_name" ).on( "focus", function ( ) {
    $( "form input[name='flagger_type']" ).click( );
  } );
  $( "form #resolver_name" ).userAutocomplete( { idEl: $( "#resolver_user_id" ) } );
  $( "form #taxon_name" ).taxonAutocomplete( { idEl: $( "#taxon_id" ) } );
  $( "form select[name='flaggable_type']" ).change( function ( ) {
    if ( $( this ).val( ) === "all" || $( this ).val( ) === "Taxon" ) {
      $( "form .content-deleted" ).hide( );
    } else {
      $( "form .content-deleted" ).show( ).removeClass( "hidden" );
    }
    if ( $( this ).val( ) === "Taxon" ) {
      $( ".taxon-search" ).removeClass( "hidden" );
    } else {
      $( ".taxon-search" ).addClass( "hidden" );
      $( "#taxon_name" ).trigger( "resetAll" );
    }
    $( "form select[name='deleted']" ).val( "any" );
  } );
} );
