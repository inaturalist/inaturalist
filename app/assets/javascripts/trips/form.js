function addTaxon(taxon) {
  $('#trip_taxa').data('last-taxon', taxon)
  $('#trip_taxa').data('check-last', true)
  $('#trip_taxa_row .add_fields').click()
}
$(document).ready(function() {
  $('#trip_taxa table').dataTable({
    bPaginate: false,
    bFilter: false
  })
  $('#new_species').chooser({
    collectionUrl: 'http://'+window.location.host + '/taxa/search.json?partial=taxon',
    resourceUrl: 'http://'+window.location.host + '/taxa/{{id}}.json?partial=taxon',
    queryParam: 'q',
    afterSelect: function(item) {
      addTaxon(item)
    }
  })
  $('#trip_taxa').bind('cocoon:after-insert', function(e, inserted_item) {
    var taxon = $('#trip_taxa').data('last-taxon'),
        row = $('#trip_taxa tr:last')
    if (!taxon) {
      return
    }
    if (taxon.html) {
      $('td.name', row).html(taxon.html)
    } else {
      var css_class = 'taxon ' + taxon.rank
      if (taxon.iconic_taxon_name) css_class += ' ' + taxon.iconic_taxon_name
      var html = $('<span></span>').addClass(css_class)
      html.html($('<span class="sciname"></span>').html(taxon.name))
      $('td.name', row).html(html)
    }
    $(':input[name*=taxon_id]', row).val(taxon.id)
    $(':input[name*=observed]', row). prop('checked', $('#trip_taxa').data('check-last'))
    $('#new_species').chooser('clear')
    $('#trip_taxa').data('last-taxon', null)
    $('#trip_taxa').data('check-last', null)
  })
  $('#location :input[name=location]').latLonSelector({
    mapDiv: $('#location .map').get(0)
  })
  $('#trip_start_time, #trip_stop_time').iNatDatepicker({time:true})
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

  $('#new_goal_taxon').chooser({
    collectionUrl: 'http://'+window.location.host + '/taxa/search.json?partial=taxon',
    resourceUrl: 'http://'+window.location.host + '/taxa/{{id}}.json?partial=taxon',
    queryParam: 'q',
    afterSelect: function(item) {
      $('#trip_purposes').data('last-taxon', item)
      $('#trip_purposes_row .add_fields').click()
    }
  })
  $('#trip_purposes').bind('cocoon:after-insert', function(e, inserted_item) {
    var taxon = $('#trip_purposes').data('last-taxon'),
        row = $('#trip_purposes .nested-fields:last')
    $(':input[name*=resource_type]', row).val('Taxon')
    $(':input[name*=resource_id]', row).val(taxon.id)
    $('#new_goal_taxon').chooser('clear')
    $('#trip_purposes').data('last-taxon', null)
    row.attr('data-taxon-id', taxon.id)
    if (taxon.html && taxon.html.length > 0) {
      $('.taxonwrapper', row).html(taxon.html)
    }
    if ($('#trip_purposes').data('hide-last')) {
      row.hide()
    }
    $('#trip_purposes').data('hide-last', null)

    if (taxon.rank_level <= 10) {
      // add species and lower to trip taxa
      $('#trip_taxa').data('last-taxon', taxon)
      $('#trip_taxa_row .add_fields').click()
    } else {
      // add complete check box
      var li = $('<li></li>').data('taxon-id', taxon.id).addClass('checkbox'),
          inputId = taxon.name.toLowerCase()+'_complete',
          label = $('<label></label>').attr('for', inputId),
          checkbox = $('<input type="checkbox"/>').attr('name', inputId).attr('id', inputId)
      checkbox.data('taxon', taxon)
      label.append(checkbox)
      if (taxon.html) {
        label.append(taxon.html)
      } else {
        label.append(
          ' ',
          $('<span></span>').addClass('taxon '+taxon.rank+' '+taxon.iconic_taxon_name).append(
            '<span class="rank">'+taxon.rank+'</span>',
            ' ',
            '<span class="sciname">'+taxon.name+'</span>'
          )
        )
      }
      li.append(label)
      $('#complete_taxa').append(li)
    }
  })
  
  $('#trip_purposes').bind('cocoon:after-remove', function(e, item) {
    var taxonId = $(':input[name*=resource_id]', item).val()
    $('#complete_taxa li[data-taxon-id='+taxonId+']').remove()
  })

  $('#goal_taxa :input:checkbox').click(function() {
    if ($(this). prop('checked')) {
      $('#trip_purposes').data('last-taxon', $(this).data('taxon'))
      $('#trip_purposes').data('hide-last', true)
      $('#trip_purposes_row .add_fields').click()
    } else {
      var taxonId = $(this).data('taxon').id
      var existingInput = $('#trip_purposes :input[value='+taxonId+']')
      existingInput.parents('.nested-fields').find('.remove_fields').click()
    }
  })

  $('#complete_taxa :checkbox').on('click', function() {
    var taxonId = $(this).parents('li:first').data('taxon-id')
    if ($(this).prop('checked')) {
      console.log("[DEBUG] $('.trip-purpose-fields[data-taxon-id='+taxonId+'] :input[name*=complete]'): ", $('.trip-purpose-fields[data-taxon-id='+taxonId+'] :input[name*=complete]'))
      $('.trip-purpose-fields[data-taxon-id='+taxonId+'] :input[name*=complete]').val(true).prop('checked', true)
    } else {
      $('.trip-purpose-fields[data-taxon-id='+taxonId+'] :input[name*=complete]').val(false).prop('checked', false)
    }
  })

  $('#addfromobsbutton').bind('ajax:success', function(e, json) {
    $.each(json.saved, function() {
      addTaxon(this.taxon)
      $('#trip_taxa tr:last :input[name*="[id]"]').val(this.id)
    })
    alert(json.msg)
  })

  $('#removetaxabutton').bind('ajax:success', function(e, json) {
    $('.trip-taxa-fields').fadeOut(function() {
      $(this).remove()
      $('#trip_taxa :input').remove()
    })
  })
})
