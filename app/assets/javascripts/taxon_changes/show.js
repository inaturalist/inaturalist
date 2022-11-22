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
            var countPiece;
            if ( v.id_count === 0 ) {
              countPiece = "0";
            } else {
              countPiece = "<a href='" + v.url + "' target='_blank'>" + v.id_count + "</a>";
            }
            var taxonPiece = "<a href='" + v.taxon_url + "' target='_blank'>" + v.name + "</a>";
            var atlasPiece;
            if ( v.atlas_url === null ) {
              atlasPiece = v.atlas_string;
            } else {
              atlasPiece = "<a href='" + v.atlas_url + "' target='_blank'>" + v.atlas_string + "</a>";
            }
            var addedClass;
            if ( v.role === "warning" && v.id_count > 0 ) {
              addedClass = "dynamically_added analysis_id_warning";
            } else {
              addedClass = "dynamically_added";
            }
            var htmlString = "<tr class='" + addedClass + "'><td>" + countPiece + "</td><td>" + taxonPiece + "</td><td>" + atlasPiece + "</td></tr>";
            $( "tr.headers" ).after( htmlString );
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

  var potentialClashesLink = $( ".potential_clashes_link" );
  var oldAncestors = potentialClashesLink.data( "input-ancestry" );
  if ( $.isNumeric( oldAncestors ) ) {
    oldAncestors = [String( oldAncestors )];
  } else {
    oldAncestors = oldAncestors.split( "/" );
  }
  var oldParent = oldAncestors[oldAncestors.length - 1];
  var newTaxon = potentialClashesLink.data( "output-taxon-id" );
  var newAncestors = potentialClashesLink.data( "output-ancestry" );
  if ( $.isNumeric( newAncestors ) ) {
    newAncestors = [String( newAncestors )];
  } else {
    newAncestors = newAncestors.split( "/" );
  }
  newAncestors.push( String( newTaxon ) );
  if ( newAncestors.indexOf( oldParent ) === -1 ) {
    var newParent = newAncestors[newAncestors.length - 2];
    var href = $( "a.potential_clashes_link" ).attr( "href" );
    $( "a.potential_clashes_link" ).attr( "href", href + "?new_parent_id=" + newParent );
    $( ".potential_clashes" ).show();
  } else {
    $( ".potential_clashes" ).hide();
  }
  $( "#clashes_modal" ).on( "show.bs.modal", function ( e ) {
    var link = $( e.relatedTarget );
    $( this ).find( ".unintended-disagreements-content" ).load( link.attr( "href" ) );
  } );
} );
