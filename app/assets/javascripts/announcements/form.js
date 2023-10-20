/* global _ */
/* global I18n */
/* global PLACEMENT_CLIENTS */

$( function ( ) {
  $( "#announcement_placement" ).change( function ( ) {
    var placement = $( "#announcement_placement" ).val( );
    var clientsSelect = $( "#announcement_clients" );
    clientsSelect.empty( );
    clientsSelect.append( $( "<option value>" + I18n.t( "all" ) + "</option>" ) );
    if ( PLACEMENT_CLIENTS[placement] ) {
      _.each( PLACEMENT_CLIENTS[placement], function ( placementClient ) {
        clientsSelect.append( $( "<option value='" + placementClient + "'>" + placementClient + "</option>" ) );
      } );
      clientsSelect.attr( "size", _.min( [_.size( PLACEMENT_CLIENTS[placement] ) + 1, 5] ) );
    } else {
      clientsSelect.attr( "size", 1 );
    }
  } );
} );
