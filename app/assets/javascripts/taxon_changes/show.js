$( document ).ready( function () {
  $( ".spinner" ).hide();
  $( document ).ajaxStart( function () {
    $( ".spinner" ).show();
  } );
  $( document ).ajaxStop( function () {
    $( ".spinner" ).hide();
  } );
} );

$( function () {
  $( ".analyze_ids_button" ).on( "click", function ( event ) {
    var $this = $( this );
    event.preventDefault();
    $.ajax( {
      type: "post",
      dataType: "json",
      url: "/taxon_changes/" + $this.data( "taxon-change-id" ) + "/analyze_ids",
      success: function ( data ) {
        if ( data ) {
          $( ".analysis" ).show();
          // update header
          $( "a.analysis_input" ).attr( "href", data.analysis_header.url );
          $( "a.analysis_input" ).text( data.analysis_header.id_count );
          // update table
          $.each( data.analysis_table, function ( k, v ) {
            var $handle = $( ".analysis_" + v.taxon_id );
            $handle.attr( "href", v.url );
            $handle.text( v.id_count );
          } );
        }
      }
    } );
  } );
} );
