$(document).ready(function() {
  $('#trip_taxa table').dataTable({
    bPaginate: false,
    bFilter: false
  })
  $('#new_species').chooser({
    collectionUrl: 'http://'+window.location.host + '/taxa/autocomplete.json',
    resourceUrl: 'http://'+window.location.host + '/taxa/{{id}}.json?partial=chooser',
    afterSelect: function(item) {
      // var lastName = $('#trip_taxa input:checkbox:last').attr('name')
      // if (lastName) {
      //   var index = parseInt(lastName.match(/trip\[trip_taxa_attributes\]\[(\d+)\]/)[1]) + 1
      // } else {
      //   var index = 0
      // }
      // var tripTaxonNameBase = 'trip[trip_taxa_attributes]['+index+']'
      // var checkbox = '<input type="checkbox" id="trip_taxon_for_'+item.id+'" name="'+tripTaxonNameBase+'[observed]" checked="checked" value="1"/>',
      //     hidden = '<input type="hidden" name="'+tripTaxonNameBase+'[taxon_id]" value="'+item.id+'"/>',
      //     inputs = checkbox + hidden
      // $('#trip_taxa table').dataTable().fnAddData([
      //   inputs, 
      //   item.html
      // ])
      $('#trip_taxa_row .add_fields').click()
      // var row = $('#trip_taxa table tr:last')
      // console.log("[DEBUG] item: ", item)
      // $('td.name', row).html(item.html)
      // this.clear()
    }
  })
  $('#trip_taxa').bind('cocoon:after-insert', function(e, inserted_item) {
    var taxon = $('#new_species').chooser('selected'),
        row = $('#trip_taxa tr:last')
    $('td.name', row).html(taxon.html)
    $(':input[name*=taxon_id]', row).val(taxon.id)
    $(':input[name*=observed]', row).attr('checked', true)
    $('#new_species').chooser('clear')
  })
  $('#location :input[name=location]').latLonSelector({
    mapDiv: $('#location .map').get(0)
  })
  $('#trip_start_time, #trip_stop_time').iNatDatepicker()
  $('#trip_place_id').chooser({
    collectionUrl: 'http://'+window.location.host + '/places/autocomplete.json',
    resourceUrl: 'http://'+window.location.host + '/places/{{id}}.json?partial=autocomplete_item',
    afterSelect: function(item) {
      $(this.element).parents('form').find('input[name*="latitude"]').val(item.latitude)
      $(this.element).parents('form').find('input[name*="longitude"]').val(item.longitude)
      
      // set accuracy from bounding box
      if (item.swlat) {
        $(this.element).parents('form').find('input[name*="positional_accuracy"]').val(
          iNaturalist.Map.distanceInMeters(item.latitude, item.longitude, item.swlat, item.swlng)
        )
      }
      
      // set the map. it might be worth just using an iNat place selector and hiding the input
      $(this.element).parents('form').find('input[name*="longitude"]').change()
      if (item.swlat) {$.fn.latLonSelector.zoomToAccuracy()}
    }
  })
})