$.fn.observationFieldsForm = function(options) {
  $(this).each(function() {
    var that = this
    $('.observation_field_chooser', this).chooser({
      collectionUrl: 'http://'+window.location.host + '/observation_fields.json',
      resourceUrl: 'http://'+window.location.host + '/observation_fields/{{id}}.json',
      afterSelect: function(item) {
        $('.observation_field_chooser', that).parents('.ui-chooser:first').next('.button').click()
        $('.observation_field_chooser', that).chooser('clear')
      }
    })
    
    $('.addfieldbutton', this).hide()
    $('#createfieldbutton', this).click(ObservationFields.newObservationFieldButtonHandler)
    ObservationFields.fieldify({focus: false})
  })
}

$.fn.newObservationField = function(markup) {
  var currentField = $('.observation_field_chooser', this).chooser('selected')
  if (!currentField || typeof(currentField) == 'undefined') {
    alert('Please choose a field type')
    return
  }
  if ($('#observation_field_'+currentField.recordId, this).length > 0) {
    alert('You already have a field for that type')
    return
  }
  
  $('.observation_fields', this).append(markup)
  ObservationFields.fieldify({observationField: currentField})
}

var ObservationFields = {
  newObservationFieldButtonHandler: function() {
    var url = $(this).attr('href'),
        dialog = $('<div class="dialog"><span class="loading status">Loading...</span></div>')
    $(document.body).append(dialog)
    $(dialog).dialog({modal:true, title: "New observation field"})
    $(dialog).load(url, "format=js", function() {
      $('form', dialog).submit(function() {
        $.ajax({
          type: "post",
          url: $(this).attr('action'),
          data: $(this).serialize(),
          dataType: 'json'
        })
        .done(function(data, textStatus, req) {
          $(dialog).dialog('close')
          $('.observation_field_chooser').chooser('selectItem', data)
        })
        .fail(function (xhr, ajaxOptions, thrownError){
          alert(xhr.statusText)
        })
        return false
      })
      $(this).centerDialog()
    })
    return false
  },

  fieldify: function(options) {
    options = options || {}
    options.focus = typeof(options.focus) == 'undefined' ? true : options.focus
    $('.observation_field').not('.fieldified').each(function() {
      var lastName = $(this).siblings('.fieldified:last').find('input').attr('name')
      console.log("[DEBUG] lastName: ", lastName)
      if (lastName) {
        var index = parseInt(lastName.match(/observation_field_values_attributes\]\[(\d+)\]/)[1]) + 1
      } else {
        var index = 0
      }
      
      $(this).addClass('fieldified')
      var input = $('.ofv_input input.text', this)
      var currentField = options.observationField || $.parseJSON($(input).attr('data-json'))
      if (!currentField) return
      currentField.recordId = currentField.recordId || currentField.id
      
      $(this).attr('id', 'observation_field_'+currentField.recordId)
      $(this).attr('data-observation-field-id', currentField.recordId)
      $('.labeldesc label', this).html(currentField.name)
      $('.description', this).html(currentField.description)
      $('.observation_field_id', this).val(currentField.recordId)
      $('input', this).each(function() {
        var newName = $(this).attr('name')
          .replace(
            /observation_field_values_attributes\]\[(\d+)\]/, 
            'observation_field_values_attributes]['+index+']')
        $(this).attr('name', newName)
      })
      if (currentField.allowed_values && currentField.allowed_values != '') {
        var allowed_values = currentField.allowed_values.split('|')
        var select = $('<select></select>')
        for (var i=0; i < allowed_values.length; i++) {
          select.append($('<option>'+allowed_values[i]+'</option>'))
        }
        select.change(function() { input.val($(this).val()) })
        $(input).hide()
        $(input).after(select)
        select.val(input.val()).change()
        if (options.focus) { select.focus() }
      } else if (currentField.datatype == 'numeric') {
        var newInput = input.clone()
        newInput.attr('type', 'number')
        input.after(newInput)
        input.remove()
        if (options.focus) { newInput.focus() }
      } else if (currentField.datatype == 'date') {
        $(input).iNatDatepicker({constrainInput: true})
        if (options.focus) { input.focus() }
      } else if (currentField.datatype == 'time') {
        $(input).timepicker({})
        if (options.focus) { input.focus() }
      } else if (currentField.datatype == 'taxon') {
        var newInput = input.clone()
        newInput.attr('name', 'taxon_name')
        input.after(newInput)
        input.hide()
        $(newInput).removeClass('ofv_value_field')
        $(newInput).simpleTaxonSelector({
          taxonIDField: input
        })
      } else if (options.focus) {
        input.focus()
      }
    })
  }
}
