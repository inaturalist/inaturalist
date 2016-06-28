var DASHBOARD = {
  LOADED_AT: new Date( Date.now( ) * 1000 ).getTime( ),
  fromIDs: { }
};

if ( DASHBOARD_FROM ) {
  DASHBOARD.fromIDs[DASHBOARD_TAB] = DASHBOARD_FROM;
}

window.onpopstate = function( event ) {
  DASHBOARD.fromIDs[event.state.type] = event.state.fromID;
  DASHBOARD.loadTab( event.state.type, { noState: true } );
};

DASHBOARD.loadTab = function( tabName, options ) {
  var tab = $("a[data-tab='" + tabName + "']")
  $( "body" ).scrollTop( 0 );
  $( ".tab-content > div" ).hide( );
  $( ".dashboard_tab_row a").removeClass( "active" );
  tab.addClass( "active" );
  $( tab.data( "targetEl" ) ).
    html( "<div class='loading status'>" + I18n.t( "loading" ) + "</div>" ).show( );
  DASHBOARD.getContent( tab.data( "tab" ), options );
};

DASHBOARD.getContent = function( type, options ) {
  var fetchURL, target, params = { };
  var options = options || { };
  if ( type === "comments" ) {
    fetchURL = "/comments";
    params = { partial: true };
    target = "#comments";
  } else {
    fetchURL = "/users/dashboard_updates";
    if ( type === "yours" ) {
      params = { filter: "you" };
      target = "#updates_by_you";
    } else {
      target = "#updates";
    }
  }
  if ( DASHBOARD.fromIDs[type] ) {
    params.from = DASHBOARD.fromIDs[type];
  }
  if ( Object.keys( params ).length > 0 ) {
    fetchURL += "?" + $.param( params );
  }
  var state = { type: type, fromID: DASHBOARD.fromIDs[type] };
  if ( options.replaceState ) {
    history.replaceState( state, "" );
  } else if ( !options.noState ) {
    var dashboardParams = { tab: type };
    if ( DASHBOARD.fromIDs[type]) { dashboardParams.from = DASHBOARD.fromIDs[type]; }
    history.pushState( state, "", "/home?" + $.param( dashboardParams ) );
  }
  $.ajax( {
    type: "GET",
    url: fetchURL,
    error: function( data ) {
      console.log( "There was a problem" );
    },
    success: function( data ) {
      if ( type === "comments" ) {
        data = $("<ul/>").addClass( "timeline" ).append( data );
      }
      $( target ).html( data );

      $( "#more_pagination" ).click( function( e ) {
        e.preventDefault( );
        DASHBOARD.fromIDs["updates"] = $( this ).data( "from" );
        DASHBOARD.loadTab( "updates" );
      });

      $( "#more_pagination_you" ).click( function( e ) {
        e.preventDefault( );
        DASHBOARD.fromIDs["yours"] = $( this ).data( "from" );
        DASHBOARD.loadTab( "yours" );
      });

      if ( type !== "comments" ) {
        $( ".subscriptionsettings" ).subscriptionSettings( );
      }

    }
  });
}

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
  DASHBOARD.loadTab( DASHBOARD_TAB, { replaceState: true } );

  $( ".dashboard_tab_row a" ).on( "click", function( e ) {
    e.preventDefault( );
    DASHBOARD.loadTab( $( e.target ).data( "tab" ) );
  });

  $( "abbr.timeago" ).timeago( );
  if ( ( new Date( ) ).getTime( ) - DASHBOARD.LOADED_AT > 5000 ) {
    $( "#flash" ).hide( );
  }
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
