var DASHBOARD = {
  fromIDs: { }
};

// hide the flash message after 5 seconds
setTimeout( function( ) {
  $( "#flash" ).fadeOut( 1000 );
}, 5000 );

// set default `from` param from variable defined in view
if ( DASHBOARD_FROM ) {
  DASHBOARD.fromIDs[DASHBOARD_TAB] = DASHBOARD_FROM;
}

window.onpopstate = function( event ) {
  // set the tab's current `from` param based on the popped state
  DASHBOARD.fromIDs[event.state.type] = event.state.fromID;
  // show the tab and fetch the content
  DASHBOARD.loadTab( event.state.type, { noState: true } );
};

DASHBOARD.loadTab = function( tabName, options ) {
  var tab = $("a[data-tab='" + tabName + "']")
  $( "body" ).scrollTop( 0 );
  // hide all other tabs
  $( ".tab-content > div" ).hide( );
  $( ".dashboard_tab_row a").removeClass( "active" );
  // show this one
  tab.addClass( "active" );
  $( tab.data( "targetEl" ) ).show( );
  var type = tab.data( "tab" );
  var tabSettings = DASHBOARD.tabSettings( type );
  $( tabSettings.target ).html( "<div class='loading status'>" + I18n.t( "loading" ) + "</div>" )
  // set the browser state and URL
  DASHBOARD.setState( type, tabSettings.params, options );
  // make an API call to fetch the tab's content
  DASHBOARD.fetchContent( tabSettings.fetchURL, type, tabSettings.target );
};

DASHBOARD.tabSettings = function( type ) {
  var fetchURL, target, params = { };
  // prepare the API path and params
  if ( type === "comments" ) {
    fetchURL = "/comments";
    params = { partial: true };
    target = "#comments_target";
  } else {
    fetchURL = "/users/dashboard_updates";
    if ( type === "yours" ) {
      params = { filter: "you" };
      target = "#updates_by_you_target";
    } else if ( type === "following" ) {
      params = { filter: "following" };
      target = "#following_target";
    } else {
      target = "#updates_target";
    }
  }
  // use this tab's current `from` param
  if ( DASHBOARD.fromIDs[type] ) {
    params.from = DASHBOARD.fromIDs[type];
  }
  if ( Object.keys( params ).length > 0 ) {
    fetchURL += "?" + $.param( params );
  }
  return { fetchURL: fetchURL, params: params, target: target };
};

DASHBOARD.fetchContent = function( fetchURL, type, target ) {
  $.ajax( {
    type: "GET",
    url: fetchURL,
    error: function( data ) {
      console.log( "There was a problem" );
    },
    success: function( data ) {
      if ( type === "comments" ) {
        // the coments partial renders <li>s, so wrap in a ul.timeline
        data = $("<ul/>").addClass( "timeline" ).append( data );
      }
      // show the content
      $( target ).html( data );
      // enable jQuery click events on loaded `more` buttons
      DASHBOARD.enableMoreButtonClickEvents( target );
      if ( type !== "comments" ) {
        $( ".subscriptionsettings" ).subscriptionSettings( );
      }
    }
  });
};

DASHBOARD.enableMoreButtonClickEvents = function( target ) {
  $( target ).find( "#more_pagination" ).unbind( "click" );
  $( target ).find( "#more_pagination" ).bind( "click", function( e ) {
    e.preventDefault( );
    var tab = $( e.target ).parents( ".tab-pane:first" ).data( "tab" )
    DASHBOARD.fromIDs[tab] = $( this ).data( "from" );
    DASHBOARD.loadTab( tab );
  });
}

DASHBOARD.setState = function( type, params, options ) {
  var options = options || { };
  var state = { type: type, fromID: DASHBOARD.fromIDs[type] };
  // on page load, just replace the empty state with the default params
  if ( options.replaceState ) {
    history.replaceState( state, "" );
  }
  // with onpopstate, noState will be set since we're popping not pushing
  else if ( !options.noState ) {
    var dashboardParams = { tab: type };
    // store this tab's current `from` param in state
    if ( DASHBOARD.fromIDs[type]) { dashboardParams.from = DASHBOARD.fromIDs[type]; }
    // stores the state and changes the browser URL
    history.pushState( state, "", "/home?" + $.param( dashboardParams ) );
  }
};

DASHBOARD.loadingPanel = function( selector ) {
  $( "body" ).scrollTop( 0 );
  $( selector ).html( "<div class='loading status'>" + I18n.t( "loading" ) + "</div>" );
};

DASHBOARD.closePanel = function( element, panelType ) {
  $( "#" + panelType + "_panel" ).fadeOut( );
  var pref = { };
  pref[ "prefers_hide_" + panelType + "_onboarding" ] = true;
  updateSession( pref );
};

$( function( ) {
  // load the default tab from a variable set in the view
  // make sure to replaceState and not setState as this is the initial load
  DASHBOARD.loadTab( DASHBOARD_TAB, { replaceState: true } );

  // prepare the click events for the tab labels
  $( ".dashboard_tab_row a" ).on( "click", function( e ) {
    e.preventDefault( );
    DASHBOARD.loadTab( $( e.target ).data( "tab" ) );
  });

  $( "abbr.timeago" ).timeago( );
  var dayInSeconds = 24 * 60 * 60,
      now = new Date( ),
      monthNames = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ];

  var elt = $( "abbr.compact.date:first" );
  if ( elt.length > 0 ) {
    var dateString = $( elt ).attr( "title" ).split( "T" )[0],
        timeString = $( elt ).attr( "title" ).split( "T" )[1],
        d = new Date( Date.parse( $( elt ).attr( "title" )));

    $( "abbr.compact.date" ).each( function( ) {
      var dateString = $( this ).attr( "title" ).split( "T" )[0],
          timeString = $( this ).attr( "title" ).split( "T" )[1],
          d = new Date( Date.parse( $( elt ).attr( "title" )));
      if ( !timeString.indexOf( ":" ) || typeof( d ) != "object" ) { return; }
      if ( now.getFullYear( ) == d.getFullYear( ) &&
           now.getMonth( ) == d.getMonth( ) &&
           now.getDate( ) == d.getDate( ) ) {
        return;
      }
      $( this ).html( monthNames[d.getMonth( )] + " " + d.getDate( ) );
    })
  }

  $( "#subscribeModal" ).on( "show.bs.modal", function( e ) {
    var that = $( this );
    taxonLabel = that.find( "#subscribeTaxonLabel" );
    subscribe_type = ( taxonLabel.css( "display" ) == "none" ) ? "place" : "taxon";
    subscribe_url = "/subscriptions/new?type=" + subscribe_type +
      "&partial=form&authenticity_token=" + $( "meta[name=csrf-token]" ).attr( "content" );
    $.ajax( {
      url: subscribe_url,
      cache: false,
      success: function( html ) {
        that.find( ".modal-body" ).append( html );
      }
    });
  });

  $( "#subscribeModal" ).on( "hide.bs.modal", function( e ) {
    $( this ).find( ".modal-body" ).children( "form" ).remove( );
  });

  $( "a[data-subscribe-type]" ).click( function( e ) {
    subscribeType = $( this ).data( "subscribe-type" );
    if ( subscribeType == "taxon" ) {
      $( "#subscribeTaxonLabel" ).show( );
      $( "#subscribePlaceLabel" ).hide( );
      $( "#subscribeTaxonBody" ).show( );
      $( "#subscribePlaceBody" ).hide( );
    } else {
      $( "#subscribePlaceLabel" ).show( );
      $( "#subscribeTaxonLabel" ).hide( );
      $( "#subscribePlaceBody" ).show( );
      $( "#subscribeTaxonBody" ).hide( );
    }
  });

  $( "a[data-panel-type]" ).click( function( e ) {
    e.preventDefault( );
    panelType = $( this ).data( "panel-type" );
    DASHBOARD.closePanel( this, panelType );
  });

  $( "[data-toggle=popover]" ).popover( );

  $( ".dashboard_tab" ).click( function( ) {
     $( ".dashboard_tab" ).removeClass( "active" );
     $( this ).addClass( "active" );
  });

  $( "html" ).on( "mouseup", function( e ) {
    if ( !$( e.target ).closest( ".popover" ).length ) {
      $( ".popover" ).each( function( ) {
        $( this.previousSibling ).popover( "hide" );
      });
    }
  });

});
