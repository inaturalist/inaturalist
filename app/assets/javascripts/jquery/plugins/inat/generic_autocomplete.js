var genericAutocomplete = { };

genericAutocomplete.createWrappingDiv = function( field, options ) {
  if( !field.parent().hasClass( "ac-chooser" ) ) {
    var wrappingDiv = $( "<div/>" ).addClass( "ac-chooser" );
    field.wrap( wrappingDiv );
    if( options.bootstrapClear ) {
      var removeIcon = $( "<span/>" ).
        addClass( "searchclear glyphicon glyphicon-remove-circle" );
      field.parent( ).append( removeIcon );
      removeIcon.on( "click", function( ) {
        field.trigger( "resetAll" );
      });
    }
  }
};

genericAutocomplete.menuClosed = function( ) {
  return ( $("ul.ac-menu:visible").length == 0 );
};


genericAutocomplete.focus = function( e, ui ) {
  var ac = $(this).data( "uiAutocomplete" );
  var li = ac.menu.element.find("li#ui-id-"+ ui.item.id);
  li.parent( ).find( "li" ).removeClass( "active" );
  li.addClass( "active" );
  return false;
};

genericAutocomplete.renderItem = function( ul, item ) {
  var li = $( "<li/>" ).addClass( "ac-result" ).
    data( "item.autocomplete", item ).
    append( genericAutocomplete.template( item ) ).appendTo( ul );
  return li;
};

genericAutocomplete.renderMenu = function( ul, items ) {
  var that = this;
  ul.removeClass( "ui-corner-all" ).removeClass( "ui-menu" );
  ul.addClass( "ac-menu" );
  $.each( items, function( index, item ) {
    that._renderItemData( ul, item );
  });
};

$.fn.genericAutocomplete = function( options ) {
  options = options || { };
  var field = this;
  if( !options.idEl ) { return; }
  if( !field || field.length < 1 ) { return; }
  var createWrappingDiv = options.createWrappingDiv ||
    genericAutocomplete.createWrappingDiv;
  createWrappingDiv( field, options );
  field.wrappingDiv = field.closest( ".ac-chooser" );
  field.searchClear = field.wrappingDiv.find( ".searchclear" )[0];
  field.selection = null;
  if( field.searchClear ) { $(field.searchClear).hide( ); }
  // search is strangely the event when the (x) is clicked in the
  // text field search box. We want to restore all defaults
  field.on( "search", function ( ) {
    field.val( "" );
    field.trigger( "resetSelection" );
    return false;
  });

  field.select = function( e, ui ) {
    // show the title in the text field
    if( ui.item.id ) {
      field.val( ui.item.title );
    }
    // set the hidden id field
    options.idEl.val( ui.item.id );
    if( options.afterSelect ) { options.afterSelect( ui ); }
    e.preventDefault( );
    return false;
  };

  field.template = options.template || field.template || function( item ) {
    var wrapperDiv = $( "<div/>" ).addClass( "ac" ).attr( "id", item.id );
    var labelDiv = $( "<div/>" ).addClass( "ac-label" );
    labelDiv.append( $( "<span/>" ).addClass( "title" ).
      append( item.title ));
    wrapperDiv.append( labelDiv );
    return wrapperDiv;
  };

  field.renderItem = function( ul, item ) {
    var li = $( "<li/>" ).addClass( "ac-result" ).data( "item.autocomplete", item ).
      append( field.template( item, field.val( ))).
      appendTo( ul );
    if( options.extraClass ) {
      li.addClass( options.extraClass );
    }
    return li;
  };

  var ac = field.autocomplete({
    minLength: 1,
    delay: 50,
    source: options.source,
    select: options.select || field.select,
    focus: options.focus || genericAutocomplete.focus
  }).data( "uiAutocomplete" );
  // modifying _move slightly to prevent scrolling with arrow
  // keys past the top or bottom of the autocomplete menu
  ac._move = function( direction, e ) {
    if( !this.menu.element.is( ":visible" ) ) {
      this.search( null, e );
      return;
    }
    // preventing scrolling past top or bottom
    if( this.menu.isFirstItem( ) && /^previous/.test( direction ) ||
        this.menu.isLastItem( ) && /^next/.test( direction ) ) {
      return;
    }
    this.menu[ direction ]( e );
  };
  ac._close = function( event ) {
    if( this.keepOpen ) { return; }
    if( this.menu.element.is( ":visible" ) ) {
      var that = this;
      that.menu.blur( );
      // delaying the close slightly so that the keydown callback below
      // happens before the menu has disappeared. So the return key
      // doesn't automatically submit the form unless we want that
      setTimeout( function( ){
        that.menu.element.hide( );
        that.isNewMenu = true;
        that._trigger( "close", event );
      }, 10 );
    }
  };
  // custom simple _renderItem that gives the LI's class ac-result
  ac._renderItem = field.renderItem;
  // custom simple _renderMenu that removes the ac-menu class
  ac._renderMenu = options.renderMenu || genericAutocomplete.renderMenu
  field.keydown( function( e ) {
    var key = e.keyCode || e.which;
    // return key
    if( key === 13 ) {
      // Absolutely prevent form submission if preventEnterSubmit has been
      // explicitly set, or allow submit when AC menu is closed, or always if
      // allowEnterSubmit. So the default behavior is for ENTER to select an
      // option when the menu is open but not submit the form, and if the menu
      // is closed and the input has focus, ENTER *will* submit the form
      if(
        !options.preventEnterSubmit
        && ( options.allowEnterSubmit || genericAutocomplete.menuClosed( ) )
      ) {
        field.closest( "form" ).submit( );
      }
      return false;
    }
    if( field.searchClear ) {
      setTimeout( function( ) {
        field.val( ) ? $(field.searchClear).show( ) : $(field.searchClear).hide( );
      }, 1 );
    }
    if( field.val( ) && options.resetOnChange === false ) { return; }
    // keys like arrows, tab, shift, caps-lock, etc. won't change
    // the value of the field so we don't need to reset the selection
    nonCharacters = [ 9, 16, 17, 18, 19, 20, 27, 33,
      34, 35, 36, 37, 38, 39, 40, 91, 93, 144, 145 ];
    if( _.includes( nonCharacters, key ) ) { return; }
    field.trigger( "resetSelection" );
  });
  field.keyup( function( e ) {
    if( !field.val( ) ) {
      field.trigger( "resetSelection" );
    }
  });
  // show the results anytime the text field gains focus
  field.bind( "focus", function( ) {
    // don't redo the search if there are results being shown
    if( genericAutocomplete.menuClosed( ) ) {
      $(this).autocomplete( "search", $(this).val( ));
    }
  });
  field.bind( "click", function( ) {
    // don't redo the search if there are results being shown
    if( genericAutocomplete.menuClosed( ) ) {
      $(this).autocomplete( "search", $(this).val( ));
    }
  });
  field.bind( "assignSelection", function( e, s, opts ) {
    opts = opts || { };
    options.idEl.val( s.id );
    field.val( s.title );
    field.selection = s;
    if( field.searchClear ) { $(field.searchClear).show( ); }
  });
  field.bind( "resetSelection", function( e ) {
    if( options.idEl.val( ) !== null ) {
      options.idEl.val( null );
      if( options.afterUnselect ) { options.afterUnselect( ); }
    }
    field.selection = null;
  });
  field.bind( "resetAll", function( e ) {
    field.trigger( "resetSelection" );
    field.val( null );
    if( field.searchClear ) { $(field.searchClear).hide( ); }
  });
  if( options.allowPlaceholders !== true ) {
    field.blur( function( ) {
      if( options.resetOnChange === false && field.selection ) {
        field.val( field.selection.title );
      }
      // adding a small timeout to allow the autocomplete JS to make
      // a selection or not before deciding if we need to clear the field
      setTimeout( function( ) {
        if( !options.idEl.val( ) && genericAutocomplete.menuClosed( ) ) {
          field.val( null );
          field.trigger( "resetSelection" );
          if( field.searchClear ) { $(field.searchClear).hide( ); }
        }
      }, 20);
    });
  }

  return ac;
};
