function updatePositions( container, sortable ) {
  var $selection = $( sortable + ":visible", container );
  $selection.each( function ( ) {
    $( "input[name*=\"position\"]", this ).val( $selection.index( this ) );
    $( "input[name*=\"position\"]", this ).parents( "form:first" ).submit( );
  } );
}
$( "ul.names" ).sortable( {
  items: "> li",
  cursor: "move",
  placeholder: "stacked sorttarget",
  update: function ( ) {
    if ( $( "li:first-child .taxon_name.invalid" ).length > 0 ) {
      $( this ).sortable( "cancel" );
      alert( I18n.t( "only_valid_names_can_be_the_default" ) );
      return;
    }
    updatePositions( this, "li" );
  }
} );
