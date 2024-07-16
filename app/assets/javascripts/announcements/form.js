/* global _ */
/* global I18n */
/* global PLACEMENT_CLIENTS */
/* global TARGET_GROUP_PARTITIONS */

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

  $( "#announcement_target_group_type" ).change( function ( ) {
    var targetGroupType = $( "#announcement_target_group_type" ).val( );
    var partitionSelect = $( "#announcement_target_group_partition" );
    if ( targetGroupType ) {
      partitionSelect.prop( "disabled", false );
    } else {
      partitionSelect.val( null );
      partitionSelect.prop( "disabled", true );
    }
    partitionSelect.empty( );
    if ( TARGET_GROUP_PARTITIONS[targetGroupType] ) {
      _.each( TARGET_GROUP_PARTITIONS[targetGroupType], function ( partition ) {
        partitionSelect.append( $( "<option value='" + partition + "'>" + partition + "</option>" ) );
      } );
    } else {
      partitionSelect.append( $( "<option value>" + I18n.t( "none" ) + "</option>" ) );
    }
  } );
} );
