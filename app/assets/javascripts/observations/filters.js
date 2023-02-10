/* eslint-disable */

// Behavior for the observations filter widget ... thing.
$(document).ready(function() {
  $('.iconic_taxon_filter input').change(function() {
    $(this).siblings('label').toggleClass('selected');
  });
  $('.iconic_taxon_filter input:checked').each(function() {
    $(this).siblings('label').addClass('selected');
  });
});

function selectAllIconicTaxa() {
  $('.iconic_taxon_filter input').each(function() {
    this.checked = true;
    $(this).siblings('label').addClass('selected');
  });
}

function deSelectAllIconicTaxa() {
  $('.iconic_taxon_filter input').each(function() {
    this.checked = false;
    $(this).siblings('label').removeClass('selected');
  });
}

function toggleFilters(link, options) {
  var options = $.extend({}, options);
  if ($('#filters:visible').length == 0) {
    showFilters(link, options)
  } else {
    hideFilters(link, options)
  }
}

function showFilters(link, options) {
  var options = $.extend({}, options)
  $('#filters').show()
  if (!options.skipClass) {
    $(link).addClass('open')
  }
  $('#filters input[name=filters_open]').val(true)
  if ( $('#filters .simpleTaxonSelector').length == 0 && !options.skipTaxonAutocomplete ) {
    $('#filters input[name=taxon_name]').taxonAutocomplete()
  }
  if ( $( "#place_filter .ui-widget" ).length === 0 ) {
    var chosenPlaceJson = $( "#filters input[name=place_id]" ).attr( "data-json" );
    $( "#filters input[name=place_id]" ).chooser( {
      collectionUrl: "/places/autocomplete.json",
      resourceUrl: "/places/{{id}}.json?partial=autocomplete_item",
      chosen: chosenPlaceJson ? JSON.parse( chosenPlaceJson ) : null
    } );
  }
  if ( $( "#not_in_place_filter .ui-widget" ).length === 0 ) {
    var chosenNotInPlaceJson = $( "#filters input[name=not_in_place]" ).attr( "data-json" );
    $( "#filters input[name=not_in_place]" ).chooser( {
      collectionUrl: "/places/autocomplete.json",
      resourceUrl: "/places/{{id}}.json?partial=autocomplete_item",
      chosen: chosenNotInPlaceJson ? JSON.parse( chosenNotInPlaceJson ) : null
    } );
  }
}

function hideFilters(link, options) {
  var options = $.extend({}, options)
  $('#filters').hide()
  if (!options.skipClass) {
    $(link).removeClass('open')
  }
  $('#filters input[name=filters_open]').val(false)
}

function deselectAll() {
  $('#filters :text, #fitlers :input[type=hidden], #fitlers select').val(null)
  $('#filters :input:checkbox').prop('checked', false)
  deSelectAllIconicTaxa()
  $('#filters input[name=place_id]').chooser('clear', {bubble:false})
  $.fn.simpleTaxonSelector.unSelectTaxon('#filters .simpleTaxonSelector')
}

function setFiltersFromQuery(query) {
  deselectAll()
  var params = $.deparam(query);
  params.has = params.has || [ ];
  if( params.photos === "true" ) { params.has.push("photos"); }
  if( params.sounds === "true" ) { params.has.push("sounds"); }
  $.each(params, function(k,v) {
    if (k != 'iconic_taxa' && k != 'has') {
      $('#filters :input:radio[name="'+k+'"][value="'+v+'"]').prop('checked', true)
    }
    if ($.isArray(v)) {
      v2 = v.join(',')
      $('#filters :input[name="'+k+'[]"]').not(':checkbox, :radio').val(v2)
    } else {
      $('#filters :input[name="'+k+'"]').not(':checkbox, :radio').val(v)
    }
    if ( k === "place_id" ) {
      if ( v === "any" ) {
        $('#filters input[name=place_id]').chooser( "clear" );
      } else {
        $('#filters input[name=place_id]').chooser( "selectId", v );
      }
    } else if ( k === "not_in_place" ) {
      if ( v === "any" ) {
        $('#filters input[name=not_in_place]').chooser( "clear" );
      } else {
        $('#filters input[name=not_in_place]').chooser( "selectId", v );
      }
    } else if (k == 'taxon_id') {
      $.fn.simpleTaxonSelector.selectTaxonFromId('#filters .simpleTaxonSelector', v)
    } else if (k == 'iconic_taxa' || k == 'has' || k == 'month') {
      $.each(v, function(i,av) {
        $selection = $('#filters :input:checkbox[name="'+k+'[]"][value='+av+']')
        $selection.prop('checked', true)
        if (k == 'iconic_taxa') {
          $selection.siblings('label').addClass('selected');
        }
      })
    } 
    else if (k == 'projects') {
      $('#filters :input[name="projects[]"]').val(v)
    }
  })
}
