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