function resetFunction() {
  $( "tr.dynamically_added" ).remove();
  $( ".analysis" ).hide();
}

$( function () {
  $( ".analyze_ids_button" ).on( "click", function ( event ) {
    resetFunction();
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
              var addedClass;
              if ( v.role === "warning" && v.id_count > 0 ) {
                addedClass = "dynamically_added analysis_id_warning";
              } else {
                addedClass = "dynamically_added";
              }
              var htmlString = "<tr class='" + addedClass + "'><td>" + countPiece + "</td><td>" + taxonPiece + "</td><td>" + atlasPiece + "</td></tr>";
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

  var potential_clashes_link = $( ".potential_clashes_link" )
  var old_ancestors = potential_clashes_link.data( "input-ancestry" )
  if( $.isNumeric( old_ancestors ) ){
    old_ancestors = [ String( old_ancestors ) ];
  }else{
    old_ancestors = old_ancestors.split( "/" )
  }
  var old_parent = old_ancestors[old_ancestors.length - 1];
  var new_taxon = potential_clashes_link.data( "output-taxon-id" );
  var new_ancestors = potential_clashes_link.data( "output-ancestry" );
  if( $.isNumeric( new_ancestors ) ){
    new_ancestors = [ String( new_ancestors ) ];
  }else{
    new_ancestors = new_ancestors.split( "/" )
  }
  new_ancestors.push( String(new_taxon) );
  if( new_ancestors.indexOf( old_parent ) == -1 ){
    var new_parent = new_ancestors[new_ancestors.length - 2];
    var _href = $("a.potential_clashes_link").attr("href");
    $("a.potential_clashes_link").attr("href", _href + '?new_parent_id=' + new_parent);
    $('.potential_clashes').show();
  }else{
    $('.potential_clashes').hide();
  }
  $("#clashes_modal").on("show.bs.modal", function(e) {
    var link = $(e.relatedTarget);
    $(this).find(".modal-body").load(link.attr("href"));
  });
} );
