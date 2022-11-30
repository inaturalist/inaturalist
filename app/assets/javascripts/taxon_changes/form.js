var spinnerNeeded = false;

function rearrangeTaxonFieldsets() {
  var changeType = $( "input[name='taxon_change[type]']:checked" ).val() || $( "input[name*='[type]']" ).val();
  if ( changeType === "TaxonStage" ) {
    $( "#singletaxon" ).removeClass( "right" ).addClass( "left" ).show();
    $( "#multiple_taxa" ).removeClass( "right" ).addClass( "left" ).hide();
    $( "#singletaxon legend" ).text( I18n.t( "output_taxon" ) );
    $( "#move-children" ).hide();
    $( "#id_analysis" ).hide();
  } else if ( changeType === "TaxonDrop" ) {
    $( "#singletaxon" ).removeClass( "right" ).addClass( "left" ).show();
    $( "#multiple_taxa" ).removeClass( "right" ).addClass( "left" ).hide();
    $( "#singletaxon legend" ).text( I18n.t( "input_taxon" ) );
    $( "#move-children" ).hide();
    $( "#id_analysis" ).hide();
  } else if ( changeType === "TaxonSwap" || changeType === "TaxonMerge" ) {
    $( "#singletaxon" ).removeClass( "left" ).addClass( "right" ).show();
    $( "#singletaxon legend" ).text( I18n.t( "output_taxon" ) );
    $( "#multiple_taxa" ).removeClass( "right" ).addClass( "left" ).show();
    $( "#id_analysis" ).hide();
    if ( changeType === "TaxonSwap" && $( "#multiple_taxa .taxon_change_taxon:visible" ).length > 0 ) {
      $( "#multiple_taxa .add_taxon_link" ).hide();
    } else {
      $( "#multiple_taxa .add_taxon_link" ).show();
    }
    $( "#multiple_taxa legend" ).text( I18n.t( "input_taxon" ) );
    $( "#move-children" ).show();
  } else {
    $( "#singletaxon" ).removeClass( "right" ).addClass( "left" ).show();
    $( "#singletaxon legend" ).text( I18n.t( "input_taxon" ) );
    $( "#multiple_taxa" ).removeClass( "left" ).addClass( "right" ).show();
    $( "#multiple_taxa .add_taxon_link" ).show();
    $( "#multiple_taxa legend" ).text( I18n.t( "output_taxon" ) );
    $( "#move-children" ).hide();
    $( "#id_analysis" ).show();
  }
}

function removeFunction( $this ) {
  var removedId = $this.prev().attr( "id" ).replace( "taxon_change_taxon_change_taxa_attributes_", "" ).replace( "__destroy", "" );
  var removedElement = $( "#taxon_change_taxon_change_taxa_attributes_" + removedId + "_taxon_id" );
  removedElement.val( 0 );
  $this.prev().val( 1 );
  $this.parents( ".taxon_change_taxon" ).slideUp( function () { rearrangeTaxonFieldsets(); } ).attr( "id", "" );
}

function addTaxonChangeTaxonField( markup ) {
  var index = $( "#multiple_taxa .taxon_change_taxon" ).length;
  markup = markup.replace( /taxon_change_taxa_attributes\]\[\d+\]/g, "taxon_change_taxa_attributes][" + index + "]" );
  markup = markup.replace( /_taxon_change_taxa_attributes_\d+_/g, "_taxon_change_taxa_attributes_" + index + "_" );
  $( "#new_taxon_change_taxa" ).append( markup );
  $( "#new_taxon_change_taxa input.text:last" ).simpleTaxonSelector( {
    isActive: "any",
    includeID: true
  } );
  rearrangeTaxonFieldsets();
}

function resetFunction() {
  $( "tr.dynamically_added" ).remove();
  $( ".analysis" ).hide();
}

$( function () {
  $( ".analyze_ids_button" ).on( "click", function ( event ) {
    resetFunction();
    var inputTaxonId = $( "#taxon_change_taxon_id" ).val();
    var outputIds = [];
    $( "input[id^='taxon_change_taxon_change_taxa_attributes_']" ).each( function () {
      if ( $( this ).attr( "id" ).indexOf( "_taxon_id" ) >= 0 ) {
        var candidate = $( this ).val();
        if ( $.isNumeric( candidate ) && parseInt( candidate, 0 ) > 0 ) {
          outputIds.push( parseInt( candidate, 0 ) );
        }
      }
    } );

    var parameters = {
      input_taxon_id: inputTaxonId,
      output_taxon_ids: outputIds
    };
    var currentId = $( "#current_id" ).val();
    if ( $.isNumeric( currentId ) ) {
      parameters.id = parseInt( currentId, 0 );
    }
    event.preventDefault();
    spinnerNeeded = true;
    $.ajax( {
      type: "post",
      dataType: "json",
      data: parameters,
      url: "/taxon_changes/analyze_ids",
      success: function ( data ) {
        if ( data ) {
          spinnerNeeded = false;
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
      },
      error: function () {
        spinnerNeeded = false;
      }
    } );
  } );
} );

$( document ).ready( function () {
  $( ".taxon_change_taxon" ).each( function () {
    var taxonIDField = $( "input[name*='[taxon_id]']", this ).get( 0 );
    $( "input.text", this ).simpleTaxonSelector( {
      taxonIDField: taxonIDField,
      isActive: "any",
      includeID: true
    } );
  } );
  rearrangeTaxonFieldsets();
  $( "input[name='taxon_change[type]']" ).change( rearrangeTaxonFieldsets );
  $( "#taxon_change_description" ).textcompleteUsers( );

  $( ".spinner" ).hide();
  $( document ).ajaxStart( function () {
    if ( spinnerNeeded ) {
      $( ".spinner" ).show();
    }
  } );
  $( document ).ajaxStop( function () {
    $( ".spinner" ).hide();
  } );
} );
