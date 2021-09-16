function resetFunction() {
  $( "tr.dynamically_added" ).remove();
  $( ".analysis" ).hide();
}

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
            if ( $( "#analysis_" + v.taxon_id ).length === 0 ) {
              var countPiece;
              if ( v.id_count === 0 ) {
                countPiece = "0";
              } else {
                countPiece = "<a href='" + v.url + "', id='analysis_" + v.taxon_id + "' target='_blank'>" + v.id_count + "</a>";
              }
              var taxonPiece = "<a href='" + v.taxon_url + "', id='analysis_taxon_" + v.taxon_id + "' target='_blank'>" + v.name + "</a>";
              var atlasPiece;
              if ( v.atlas_url === null ) {
                atlasPiece = v.atlas_string;
              } else {
                atlasPiece = "<a href='" + v.atlas_url + "', id='analysis_atlas_" + v.taxon_id + "' target='_blank'>" + v.atlas_string + "</a>";
              }
              var htmlString = `
                <tr class="dynamically_added">
                  <td>` + countPiece + `</td>
                  <td>` + taxonPiece + `</td>
                  <td>` + atlasPiece + `</td>
                </tr>
              `;
              $( "tr.headers" ).after( htmlString );
            }
          } );
        }
      }
    } );
  } );
} );

$( document ).ready( function () {
  $( "#comment_body" ).textcompleteUsers( );
  $( ".spinner" ).hide();
  $( document ).ajaxStart( function () {
    $( ".spinner" ).show();
  } );
  $( document ).ajaxStop( function () {
    $( ".spinner" ).hide();
  } );

} );
