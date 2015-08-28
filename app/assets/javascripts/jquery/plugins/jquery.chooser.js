// Roughly based on http://jqueryui.com/demos/autocomplete/#combobox
(function( $ ) {
  $.widget( "ui.chooser", {
    options: {
      choiceClass: 'ui-widget ui-widget-content ui-corner-left inlineblock ui-chooser-choice',
      inputClass:  'ui-widget ui-widget-content ui-corner-left inlineblock ui-chooser-input',
      buttonClass: 'ui-corner-right ui-chooser-button ui-button-icon inlineblock',
      queryParam: 'term'
    },
    _create: function() {
      var self = this,
          source = this.options.source,
          collectionUrl = this.options.collectionUrl,
          cache = {},
          defaultSources = this.options.defaultSources || $.parseJSON($(this.element).attr('data-chooser-default-sources') || null)
      if (!collectionUrl && typeof(this.options.source) == 'string') {
        collectionUrl = this.options.collectionUrl = this.options.source
      }
      this.defaultSources = defaultSources = this.recordsToItems(defaultSources)
      this.options.chosen = this.options.chosen || $.parseJSON($(this.element).attr('data-chooser-chosen') || null)
      this.options.source = this.options.source || defaultSources
      var markup = this.setupMarkup()
      this.selectDefault()
      if (!this.options.collectionUrl && this.options.source.length == 0 || typeof(this.options.source[0]) == 'string') {
        var that = this
        $(this.markup.input).blur(function() {
          if ($(that.markup.input).is(':visible')) {
            that.selectItem($(that.markup.input).val())
          }
        })
      }
      markup.input.autocomplete({
        html: true,
        minLength: 0,
        select: function(ui, event) {
          if (event.item.forceRemote) {
            self.options.source = collectionUrl
            $(ui.target).autocomplete('search', ui.target.value)
          } else if (event.item.clear) {
            $(self).data('previous', null)
            self.clear()
          } else {
            self.selectItem(event.item)
          }
          return false
        },
        source: function(request, response) {
          var source = self.options.source
          if (request.term == '' && typeof(source) == 'string') {
            source = self.options.source = self.defaultSources
          }
          if (typeof(source) != 'string') {
            var matcher = new RegExp( $.ui.autocomplete.escapeRegex(request.term), "i" );
            var selected = $.map(source, function(src) {
              if (src.forceRemote || matcher.test(src.label)) { return src }
            })
            if (selected.length != 0) {
              if (collectionUrl && request.term != '') {
                selected.push({label: '<em>'+I18n.t('search_remote')+'</em>', value: request.term, forceRemote: true})
              }
              selected.push({label: '<em>'+I18n.t('clear')+'</em>', value: request.term, clear: true})
              response(selected)
              return
            } else {
              response([])
            }
          }
          if (cache[request.term]) {
            response(cache[request.term])
            return
          }
          
          if (!collectionUrl) { return };
          
          markup.chooseButton.hide()
          markup.loadingButton.showInlineBlock()
          
          if (self.request) {
            self.request.abort()
          }
          
          self.request = $.getJSON(collectionUrl, self.options.queryParam+"="+request.term, function(json) {
            markup.chooseButton.showInlineBlock()
            markup.loadingButton.hide()
            json = self.recordsToItems(json)
            json.push({label: '<em>'+I18n.t('clear')+'</em>', value: request.term, clear: true})
            cache[request.term] = json
            response(json)
          })
        }
      })
      
      // bind button behaviors
      markup.clearButton.click(function() {
        self.clear()
      })
      
      markup.input.bind('autocompleteclose', function(e, ui) {
        if (!markup.input.is(':focus') && $(self).data('previous')) {
          self.selectItem($(self).data('previous'), {blurring: true})
        }
      })
      markup.input.bind('autocompleteopen', function(e, ui) {
        // lame hack aaround weird display bug
        if (!$(e.currentTarget).is(':visible')) {
          markup.input.autocomplete( "close" )
          return
        }
      })
      
      markup.chooseButton.click(function() {
        // close if already visible
        if (markup.input.autocomplete( "widget" ).is( ":visible" )) {
          markup.input.autocomplete( "close" )
          return
        }

        // work around a bug (likely same cause as #5265)
        $( this ).blur()
        
        $(self).data('previous', $(self).data('selected'))
        self.open()

        // pass empty string as value to search for, displaying all results
        markup.input.autocomplete( "search", "" )
        markup.input.focus()
      })
      
      // Bind ENTER in search field
      $(markup.input).keypress(function(e) {
        if (e.which == 13) {
          return false
        }
      })
    },
    
    selectDefault: function() {
      var self = this, markup = this.markup
      if (this.options.chosen) {
        var item = this.options.chosen
        if (typeof(item) != 'string') {
          item = self.recordsToItems([item])[0]
        }
        $(this).data('previous', item)
        this.selectItem(item)
      } else if ($(this.element).val() != '' && this.options.resourceUrl) {
        this.selectId($(this.element).val())
      }
    },
    
    selectId: function(id) {
      var self = this, markup = this.markup
      markup.chooseButton.hide()
      markup.loadingButton.showInlineBlock()
      var resourceUrl = this.options.resourceUrl.replace(/\{\{id\}\}/, id)
      $.getJSON(resourceUrl, function(json) {
        var item = self.recordsToItems([json])[0]
        markup.loadingButton.hide()
        self.selectItem(item)
      })
    },
    
    recordsToItems: function(records) {
      var items = [], records = records || []
      for (var i=0; i < records.length; i++) {
        if (!records[i]) { continue }
        items.push(
          $.extend(records[i], {
            label: records[i].label || records[i].html || records[i].title || records[i].name,
            value: records[i].value || records[i].title || records[i].name || records[i].id,
            recordId: records[i].id
          })
        )
      }
      return items
    },
    
    selectItem: function(item, options) {
      options = options || this.options || {}
      if (!item) {
        this.clear()
      } else {
        if (typeof(item) == 'object') {
          if (!item.label) {
            item = this.recordsToItems([item])[0]
          }
          var itemLabel = item.label || item.html,
              itemValue = item.recordId || item.value || item.id
        } else {
          var itemLabel = item,
              itemValue = item
        }
        $(this).data('selected', item)
        $(this.markup.input).hide()
        $(this.markup.choice).html(itemLabel).showInlineBlock()
        $(this.markup.chooseButton).showInlineBlock()
        $(this.markup.clearButton)
          .height(this.markup.choice.outerHeight()-2)
        $(this.markup.chooseButton)
          .height(this.markup.choice.outerHeight()-2)
        $('.ui-icon', this.markup.clearButton)
          .css('margin-top', '-' + Math.round((this.markup.choice.outerHeight() / 2) - 6) + 'px')
        $('.ui-icon', this.markup.chooseButton)
          .css('margin-top', '-' + Math.round((this.markup.choice.outerHeight() / 2) - 6) + 'px')
        $(this.markup.originalInput).val(itemValue).change()
      }
      var changed = true
      if (($(this).data('previous') && $(this).data('previous').id === item.id) || (!$(this).data('previous') && !item)) {
        changed = false
      }
      if (!options.blurring && typeof(this.options.afterSelect) == 'function' && changed) {
        this.options.afterSelect.apply(this, [item])
      }
      $(this).data('previous', null)
    },

    open: function(opts) {
      var options = this.options || {},
          opts = opts || {},
          bubble = opts.bubble == false ? false : true
      $(this).data('selected', null)
      $(this.markup.originalInput).val('')
      if (!$(this).data('previous') && bubble) {
        $(this.markup.originalInput).change()
      }
      $(this.markup.input).val('').showInlineBlock()
      $(this.markup.choice).html('').hide()
      
      $(this.markup.chooseButton).height(this.markup.input.outerHeight())
      $('.ui-icon', this.markup.chooseButton)
        .css('margin-top', '-' + Math.round((this.markup.input.outerHeight() / 2) - 6) + 'px')
    },
    
    clear: function(clearOpts) {
      var options = this.options || {}
      this.open(clearOpts)
      if (!options.blurring && typeof(this.options.afterClear) == 'function') {
        this.options.afterClear.apply(this)
      }
    },
    
    setupMarkup: function() {
      var originalInput = this.element.hide()
      this.markup = {
        originalInput: originalInput,
        wrapper: $('<div class="inlineblock ui-chooser"></div>').attr('id', originalInput.attr('id') + '_chooser'),
        input: $('<input type="text"/>')
          .addClass(this.options.inputClass)
          .attr('placeholder', originalInput.attr('placeholder'))
          .blur( function( ) {
            $(this).val( "" );
          }),
        choice: $('<div></div>')
          .addClass(this.options.choiceClass)
          .hide(),
        chooseButton: $('<button type="button" class="choosebutton">&nbsp;</button>')
          .button({
            icons: {
              primary: "ui-icon-triangle-1-s"
            },
            text: false
          })
          .removeClass( "ui-corner-all" )
          .addClass(this.options.buttonClass),
        clearButton: $('<button type="button">&nbsp;</button>')
          .button({
            icons: {
              primary: "ui-icon-cancel"
            },
            text: false
          })
          .removeClass( "ui-corner-all" )
          .addClass(this.options.buttonClass)
          .hide(),
        loadingButton: $('<button type="button" disabled="disabled">&nbsp;</button>')
          .button({
            text: false,
            disabled: true
          })
          .removeClass( "ui-corner-all" )
          .addClass(this.options.buttonClass + ' ui-icon-loading')
          .hide()
      }
      $(this.markup.originalInput).wrap(this.markup.wrapper)
      this.markup.originalInput.after(
        this.markup.input, 
        this.markup.choice, 
        this.markup.chooseButton, 
        this.markup.loadingButton, 
        this.markup.clearButton)
      this.markup.input.width(originalInput.outerWidth - this.markup.chooseButton.width() - 20)
      this.markup.choice.width(originalInput.outerWidth)
      return this.markup
    },
    destroy: function() {
      this.markup.input.remove()
      this.markup.choice.remove()
      this.markup.chooseButton.remove()
      this.markup.loadingButton.remove()
      this.markup.clearButton.remove()
      
      this.element.show();
      $.Widget.prototype.destroy.call( this );
    },
    
    getOptions: function() {
      return this.options
    },
    
    getSources: function() {
      return this.options.source
    },
    
    getItemById: function(id) {
      for (var i = this.options.source.length - 1; i >= 0; i--){
        if (this.options.source[i].id == id) { return this.options.source[i] }
      }
      return null
    },
    
    selected: function() {
      var selected = $(this).data('selected')
      return typeof(selected) == 'undefined' ? null : selected
    }
  })
})( jQuery )
