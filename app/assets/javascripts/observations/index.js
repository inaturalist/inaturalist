/**
 * Select all iconic taxa and change their label classes.
 */
function selectAllIconicTaxa() {
  $$('.iconic_taxon_filter').each(function(elt) {
    elt.down('input[type=checkbox]').checked = true;
    elt.down('label').addClassName('selected');
  });
}

/**
 * Deselect all iconic taxa and change their label classes.
 */
function deSelectAllIconicTaxa() {
  $$('.iconic_taxon_filter').each(function(elt) {
    elt.down('input[type=checkbox]').checked = false;
    elt.down('label').removeClassName('selected');
  });
}


Event.observe(window, 'load', function() {
  // Add click behavior for iconic taxon checkboxes
  $$('.iconic_taxon_filter').each(function(filter) {
    filter.down('input').observe('change', function(e) {
      var filter = Event.element(e).up('.iconic_taxon_filter');
      filter.down('label').toggleClassName('selected');
      new Effect.Highlight('submit_filters_button', {
        startcolor: '#1E90FF', 
        endcolor: '#3366CC',
        restorecolor: '#3366CC'}); // just until we get the AJAX form submission working
    });
  });
  $$('#filters input').each(function(input) {
    input.observe('change', function(e) {
      $('time_to').show();
    });
  });
});
