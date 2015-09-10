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
  if ($('#filters .simpleTaxonSelector').length == 0) {
    $('#filters input[name=taxon_name]').taxonAutocomplete()
  }
  if ($('#place_filter .ui-widget').length == 0) {
    $('#filters input[name=place_id]').chooser({
      collectionUrl: '/places/autocomplete.json',
      resourceUrl: '/places/{{id}}.json?partial=autocomplete_item',
      chosen: eval('(' + $('#filters input[name=place_id]').attr('data-json') + ')')
    })
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
  $('#filters :input:checkbox').attr('checked', false)
  deSelectAllIconicTaxa()
  $('#filters input[name=place_id]').chooser('clear', {bubble:false})
  $.fn.simpleTaxonSelector.unSelectTaxon('#filters .simpleTaxonSelector')
}

function setFiltersFromQuery(query) {
  deselectAll()
  var params = $.deparam(query)
  $.each(params, function(k,v) {
    if (k != 'iconic_taxa' && k != 'has') {
      $('#filters :input:radio[name="'+k+'"][value="'+v+'"]').attr('checked', true)
    }
    if ($.isArray(v)) {
      v = v.join(',')
      $('#filters :input[name="'+k+'[]"]').not(':checkbox, :radio').val(v)
    } else {
      $('#filters :input[name="'+k+'"]').not(':checkbox, :radio').val(v)
    }
    if (k == 'place_id') {
      $('#filters input[name=place_id]').chooser('selectId', v)
    } else if (k == 'taxon_id') {
      $.fn.simpleTaxonSelector.selectTaxonFromId('#filters .simpleTaxonSelector', v)
    } else if (k == 'iconic_taxa' || k == 'has') {
      $.each(v, function(i,av) {
        $selection = $('#filters :input:checkbox[name="'+k+'[]"][value='+av+']')
        $selection.attr('checked', true)
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
