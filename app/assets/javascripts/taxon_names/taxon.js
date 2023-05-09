$( ".btn-submit" ).click( function ( ) {
  var container = $( "#" + $( this ).data( "target" ) );
  $( "form", container ).submit( );
  $( this ).attr( "disabled", false ).addClass( "hidden" );
} );

function updatePositions( container, sortable ) {
  var elements = $( sortable + ":visible", container );
  elements.each( function () {
    $( "input[name*=\"position\"]", this ).val( elements.index( this ) );
  } );
  $( ".btn-submit[data-target='" + container.id + "']" ).attr( "disabled", false ).removeClass( "hidden" );
}

$( "ul.names" ).sortable( {
  items: "> li",
  cursor: "move",
  placeholder: "stacked sorttarget",
  update: function ( ) {
    updatePositions( this, "li" );
  }
} );
