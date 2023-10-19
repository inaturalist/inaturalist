/* global _ */
/* global I18n */
/* global PLACEMENT_PLATFORMS */

$( function ( ) {
  $( "#announcement_placement" ).change( function ( ) {
    var placement = $( "#announcement_placement" ).val( );
    var platformsSelect = $( "#announcement_platforms" );
    platformsSelect.empty( );
    platformsSelect.append( $( "<option value>" + I18n.t( "all" ) + "</option>" ) );
    if ( PLACEMENT_PLATFORMS[placement] ) {
      _.each( PLACEMENT_PLATFORMS[placement], function ( placementPlatform ) {
        platformsSelect.append( $( "<option value='" + placementPlatform + "'>" + placementPlatform + "</option>" ) );
      } );
      platformsSelect.attr( "size", _.min( [_.size( PLACEMENT_PLATFORMS[placement] ) + 1, 5] ) );
    } else {
      platformsSelect.attr( "size", 1 );
    }
  } );
} );
