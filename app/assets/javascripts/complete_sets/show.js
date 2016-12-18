$('.show_listings_element').on( "click", function( e ) {
  e.preventDefault( );
  var taxonID = $(this).attr("data-taxon-id");
  getListings( taxonID );
});

$('.destroy_element').on( "click", function( e ) {
  e.preventDefault( );
  var taxonID = $(this).attr("data-taxon-id");
  var confirmText = "This will destroy all the listed taxa that are of this taxon (or any descendants) for this place (or any standard descendants). This can be very destructive, are you sure?";
  if(confirm(confirmText)) {
    destroy( taxonID );
  }
});


getListings = function( taxon ) {
  if( !taxon ) { return; }
  var complete_set = $( "#set" );
  placeID = complete_set.data( "place-id" );
  complete_setID = complete_set.data( "complete-set-id" );
  $.ajax({
    type: "get",
    dataType: "json",
    url: "/complete_sets/" + complete_setID + "/get_relevant_listings",
    data: { taxon_id: taxon, place_id: placeID },
    success: function( s ) {
      console.log(s);
      panel = $( "#right" );
      panel.html( "" );
      panel.append( $( "<h4>" ).text( "Listed Taxa" ) );
      $.each(s, function(key,value) {
        var explodeLink = $( "<a href='/listed_taxa/"+value.id+"'>" ).text( value.taxon.name+" in "+value.place.name);
        panel.append( explodeLink );
        panel.append( "<br>" );
      });
    },
    error: function( e ) {
    }
  });
};

destroy = function( taxon ) {
  if( !taxon ) { return; }
  var complete_set = $( "#set" );
  placeID = complete_set.data( "place-id" );
  complete_setID = complete_set.data( "complete-set-id" );
  $.ajax({
    type: "post",
    dataType: "json",
    url: "/complete_sets/" + complete_setID + "/destroy_relevant_listings",
    data: { taxon_id: taxon, place_id: placeID },
    success: function( s ) {
      console.log("sucess");
    },
    error: function( e ) {
      console.log("error");
    }
  });
};