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
  },

  showObservationFieldsDialog: function(options) {
    options = options || {}
    var url = options.url || '/observations/'+window.observation.id+'/fields',
        title = options.title || 'Observation fields',
        originalInput = options.originalInput
    var dialog = $('#obsfielddialog')
    if (dialog.length == 0) {
      dialog = $('<div id="obsfielddialog"></div>').addClass('dialog').html('<div class="loading status">Loading...</div>')
    }
    dialog.load(url, function() {
      var diag = this
      $(this).observationFieldsForm()
      $(this).centerDialog()
      $('form:has(input[required])', this).submit(checkFormForRequiredFields)

      if (originalInput) {
        var form = $('form', this)
        $(form).submit(function() {
          var ajaxOptions = {
            url: $(form).attr('action'),
            type: $(form).attr('method'),
            data: $(form).serialize(),
            dataType: 'json'
          }
          $.ajax(ajaxOptions).done(function() {
            $.rails.fire($(originalInput), 'ajax:success')
            $(diag).dialog('close')
          }).fail(function() {
            alert('Failed to add to project')
          })
          return false
        })
      }
    })
    dialog.dialog({
      modal: true,
      title: title,
      width: 600,
      minHeight: 400
    })
  }
}

// the following stuff doesn't have too much to do with observation fields, but it's at least tangentially related
$(document).ready(function() {
  $('#project_menu .addlink, .project_invitation .acceptlink').bind('ajax:success', function(e, json, status) {
    var observationId = (json && json.observation_id) || $(this).data('observation-id') || window.observation.id
    if (json && json.project && json.project.project_observation_fields && json.project.project_observation_fields.length > 0) {
      ObservationFields.showObservationFieldsDialog({
        url: '/observations/'+observationId+'/fields?project_id='+json.project_id,
        title: 'Project observation fields for ' + json.project.title,
        originalInput: this
      })
    }
  }).bind('ajax:error', function(e, xhr, error, status) {
    var json = $.parseJSON(xhr.responseText),
        projectId = json.project_observation.project_id || $(this).data('project-id'),
        observationId = json.project_observation.observation_id || $(this).data('observation-id') || window.observation.id
    if (json.error.match(/observation field/)) {
      ObservationFields.showObservationFieldsDialog({
        url: '/observations/'+observationId+'/fields?project_id='+projectId,
        title: 'Project observation fields',
        originalInput: this
      })
    } else if (json.error.match(/must belong to a member/)) {
      showJoinProjectDialog(projectId, {originalInput: this})
    } else {
      alert(json.error)
    }
  })
  $('#project_menu .removelink, .project_invitation .removelink').bind('ajax:error', function(e, xhr, error, status) {
    alert(xhr.responseText)
  })
})
