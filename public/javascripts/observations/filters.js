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
    $('#filters input[name=taxon_name]').simpleTaxonSelector()
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
