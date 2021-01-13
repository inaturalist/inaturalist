$( document ).ready( function( ) {

  $( "#map" ).taxonMap( { preserveViewport: PRESERVE_VIEWPORT, placement: "projects-show-traditional" } );
  window.map = $( "#map" ).data( "taxonMap" );
  for ( var i=0; i < KML_ASSET_URLS.length; i++ ) {
    lyr = new google.maps.KmlLayer( KML_ASSET_URLS[i], { preserveViewport: PRESERVE_VIEWPORT } );
    lyr.setMap( window.map );
    kmlSet = true;
  }

  $( "#recent_observations .observations" ).loadObservations( {
    url: OBSERVATIONS_URL + "&per_page=24", style: "grid",
    success: function( r, data ) {
      $observations = $( "#recent_observations .observation" )
      $observations.each( function( ) {
        var o = {
          id: $( this ).attr( "id" ).split( "-" )[1],
          latitude: $( this ).attr( "data-latitude" ),
          longitude: $( this ).attr( "data-longitude" ),
          coordinates_obscured: $( this ).attr( "data-coordinates-obscured" ),
          taxonId: $( this ).attr( "data-taxon-id" ),
          iconic_taxon: {
            name: $( this ).attr( "data-iconic-taxon-name" )
          }
        }
        map.addObservation( o );
      } );
      if ( $observations.length == 0 ) {
        $( "#recent_observations .observations" ).html(
          $( "<div class='meta nocontent'></div>" ).html( I18n.t( "no_observations_yet" ) )
        );
      }
      var headers = r.getAllResponseHeaders( );
      var matches = headers.match( /X-Total-Entries: (\d+)/i ) || [],
          totalEntries = matches[1];
      if ( totalEntries ) {
        $( ".totalcount .count a" ).text( totalEntries );
      }
    }
  } );

  $( "#recent_observations .observationcontrols" ).
    observationControls( { div: $( "#recent_observations .observations" ), skipMap: true } );

  $( "#feature-menu" ).on( "click", function( e ) {
    e.stopPropagation( );
  } );

  $( "#feature-menu > li ").on( "click", function( ) {
    var type = $( this ).data( "type" );
    var method = "feature";
    var data = { };
    if ( type === "noteworthy" ) {
      data.noteworthy = true;
    } else if ( type === "remove" ) {
      method = "unfeature";
    }
    $( "*" ).css( "cursor", "progress" );
    $.ajax( {
      type: "PUT",
      url: "/projects/" + PROJECT_ID + "/" + method,
      data: data,
      success: function( data ) {
        location.reload( );
      },
      error: function( data ) {
        console.log( "error" );
        $( "body" ).css( "cursor", "default" );
      },
      dataType: "JSON"
    } );
  } );

} );
