/* global _ */
/* global I18n */
/* global PLACEMENT_CLIENTS */
/* global TARGET_GROUP_PARTITIONS */
/* global DISMISSIBLE_PLACEMENTS */

$( function ( ) {
  // show/hide inputs depending on placement selected
  $( "#announcement_placement" ).change( function ( ) {
    var placement = $( "#announcement_placement" ).val( );
    var clientsSelect = $( "#announcement_clients" );
    var valuesToSelect = clientsSelect.val( ) || clientsSelect.data( "originalValues" ) || [];
    clientsSelect.empty( );
    clientsSelect.append( $( "<option value>" + I18n.t( "all" ) + "</option>" ) );
    // Some placements are only relevant to certain clients, so if the user
    // chooses a placement we need to show/hide the relevant clients
    if ( PLACEMENT_CLIENTS[placement] ) {
      _.each( PLACEMENT_CLIENTS[placement], function ( placementClient ) {
        var option = $( "<option value='" + placementClient + "'>" + placementClient + "</option>" );
        if ( valuesToSelect.indexOf( placementClient ) >= 0 ) {
          option.attr( "selected", true );
        }
        clientsSelect.append( option );
      } );
      clientsSelect.attr( "size", _.min( [_.size( PLACEMENT_CLIENTS[placement] ) + 1, 5] ) );
      $( ".clients_field" ).show( );
    } else {
      clientsSelect.attr( "size", 1 );
      $( ".clients_field" ).hide( );
    }
    // Not all placements *can* be dismissed, so we hide that checkbox if the user chooses one
    if ( DISMISSIBLE_PLACEMENTS.indexOf( placement ) < 0 ) {
      $( ".dismissible_field" ).hide( );
    } else {
      $( ".dismissible_field" ).show( );
    }
  } );

  // Show / hide the clients on load
  $( "#announcement_placement" ).change();
  $( "#announcement_clients" ).data( "originalValues", $( "#announcement_clients" ).val( ) );

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

  // Enable / disable inputs that require a signed in user
  $( "[name='announcement[target_logged_in]']" ).change( function ( ) {
    var form = $( this ).parents( "form" ).get( 0 );
    const val = $( "[name='announcement[target_logged_in]']:checked", form ).val( );

    // show / hide the options that concern users
    if ( val === "yes" ) {
      $( "#logged-in-options" ).show( );
    } else {
      $( "#logged-in-options" ).hide( );
    }
  } );
  $( "[name='announcement[target_logged_in]']" ).change();
} );
