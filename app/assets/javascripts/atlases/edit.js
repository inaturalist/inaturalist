$( function ( ) {
  $( ".collapse_button" ).on( "click", function ( event ) {
    var $this = $( this );
    $this.closest( "tr" ).fadeOut();
    event.preventDefault();

    $.ajax( {
      type: "DELETE",
      url: $this.attr( "href" ),
      success: function ( data ) {
        console.log( "success" ); // eslint-disable-line no-console
        var tableRow = "<tr><td><a href=\"/places/" + data.place_id + "\">"
          + data.place_name + "</a></td><td></td></tr>";
        $( "tbody.places tr:last" ).after( tableRow );
      },
      error: function ( ) {
        console.log( "error" ); // eslint-disable-line no-console
      },
      dataType: "JSON"
    } );
  } );

  $( ".explode_button" ).on( "click", function ( event ) {
    var $this = $( this );
    $this.closest( "tr" ).fadeOut();
    event.preventDefault();
    var placeAtlasIDs = this.id.split( "_" );
    var placeID = placeAtlasIDs[0];
    var atlasID = placeAtlasIDs[1];
    $.ajax( {
      type: "POST",
      url: $this.attr( "href" ),
      data: { place_id: placeID, atlas_id: atlasID },
      success: function ( data ) {
        var tableRow = "<tr><td><a href=\"/places/" + data.place_id + "\">"
          + data.place_name + "</a></td><td></td></tr>";
        if ( $( "tbody.exploded tr:last" ) ) {
          $( "tbody.exploded" ).append( tableRow );
          $( ".no_exploded" ).fadeOut( );
        } else {
          $( "tbody.exploded tr:last" ).after( tableRow );
        }
      },
      error: function ( ) {
        console.log( "error" ); // eslint-disable-line no-console
      },
      dataType: "JSON"
    } );
  } );
} );
