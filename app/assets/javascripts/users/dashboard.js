/* global DASHBOARD_FROM, DASHBOARD_TAB, I18n, updateSession */

var DASHBOARD = {
  fromIDs: { },
  fromPage: { }
};

// hide the flash message after 5 seconds
setTimeout( function ( ) {
  $( "#flash" ).fadeOut( 1000 );
}, 5000 );

// set default `from` param from variable defined in view
if ( DASHBOARD_FROM ) {
  DASHBOARD.fromIDs[DASHBOARD_TAB] = DASHBOARD_FROM;
}

window.onpopstate = function ( event ) {
  // set the tab's current `from` param based on the popped state
  DASHBOARD.fromIDs[event.state.type] = event.state.fromID;
  // show the tab and fetch the content
  DASHBOARD.loadTab( event.state.type, { noState: true } );
};

DASHBOARD.loadTab = function ( tabName, options ) {
  var tab = $( "a[data-tab='" + tabName + "']" );
  // hide all other tabs
  $( ".tab-content > div" ).hide( );
  $( ".dashboard_tab_row a" ).removeClass( "active" );
  // show this one
  tab.addClass( "active" );
  $( tab.data( "targetEl" ) ).show( );
  var type = tab.data( "tab" );
  var tabSettings = DASHBOARD.tabSettings( type );
  DASHBOARD.startPanelLoading( tabSettings.target );
  // set the browser state and URL
  DASHBOARD.setState( type, tabSettings.params, options );
  // make an API call to fetch the tab's content
  DASHBOARD.fetchContent( tabSettings.fetchURL, type, tabSettings.target );
};

DASHBOARD.tabSettings = function ( type ) {
  var fetchURL;
  var target;
  var params = { };
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
  if ( DASHBOARD.fromPage[type] ) {
    params.page = DASHBOARD.fromPage[type];
  }
  if ( Object.keys( params ).length > 0 ) {
    fetchURL += "?" + $.param( params );
  }
  return { fetchURL: fetchURL, params: params, target: target };
};

DASHBOARD.fetchContent = function ( fetchURL, type, target ) {
  $.ajax( {
    type: "GET",
    url: fetchURL,
    error: function ( ) {
      console.log( "There was a problem" );
    },
    success: function ( data ) {
      var content = type === "comments"
        ? $( "<ul/>" ).addClass( "timeline" ).append( data )
        : data;
      DASHBOARD.finishPanelLoading( target );
      $( target ).html( content );
      // enable jQuery click events on loaded pagination buttons
      if ( $( "body" ).hasClass( "responsive" ) ) {
        DASHBOARD.enablePageButtonClickEvents( target );
      } else {
        DASHBOARD.enableMoreButtonClickEvents( target );
      }
      if ( type !== "comments" ) {
        $( ".subscriptionsettings" ).subscriptionSettings( );
      }
    }
  } );
};

DASHBOARD.enableMoreButtonClickEvents = function ( target ) {
  $( target ).find( "#more_pagination" ).unbind( "click" );
  $( target ).find( "#more_pagination" ).bind( "click", function ( e ) {
    e.preventDefault( );
    var tab = $( e.target ).parents( ".tab-pane:first" ).data( "tab" );
    DASHBOARD.fromIDs[tab] = $( this ).data( "from" );
    DASHBOARD.loadTab( tab );
  } );
};

DASHBOARD.enablePageButtonClickEvents = function ( target ) {
  $( target ).find( ".page_button" ).unbind( "click" );
  $( target ).find( ".page_button" ).bind( "click", function ( e ) {
    e.preventDefault( );
    if ( $( this ).hasClass( "disabled" ) ) { return; }
    var tab = $( e.target ).parents( ".tab-pane:first" ).data( "tab" );
    DASHBOARD.fromPage[tab] = $( this ).data( "page" );
    DASHBOARD.loadTab( tab );
  } );
};

DASHBOARD.setState = function ( type, params, options ) {
  var opts = options || { };
  var state = { type: type, fromID: DASHBOARD.fromIDs[type] };
  // on page load, just replace the empty state with the default params
  if ( opts.replaceState ) {
    window.history.replaceState( state, "" );
  } else if ( !opts.noState ) {
    var dashboardParams = { tab: type };
    // store this tab's current `from` param in state
    if ( DASHBOARD.fromIDs[type] ) { dashboardParams.from = DASHBOARD.fromIDs[type]; }
    // stores the state and changes the browser URL
    window.history.pushState( state, "", "/home?" + $.param( dashboardParams ) );
  }
};

DASHBOARD.startPanelLoading = function ( selector ) {
  var target = $( selector );
  window.scrollTo( 0, 0 );
  target.attr( "aria-busy", true );
  target.html( "<div class='loading status'>" + I18n.t( "loading" ) + "</div>" );
};

DASHBOARD.finishPanelLoading = function ( selector ) {
  $( selector ).attr( "aria-busy", false );
};

$( function ( ) {
  // load the default tab from a variable set in the view
  // make sure to replaceState and not setState as this is the initial load
  DASHBOARD.loadTab( DASHBOARD_TAB, { replaceState: true } );

  // prepare the click events for the tab labels
  $( ".dashboard_tab_row a" ).on( "click", function ( e ) {
    e.preventDefault( );
    DASHBOARD.loadTab( $( e.target ).data( "tab" ) );
  } );

  $( "abbr.timeago" ).timeago( );
  var now = new Date( );
  var monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  var elt = $( "abbr.compact.date:first" );
  if ( elt.length > 0 ) {
    $( "abbr.compact.date" ).each( function ( ) {
      var timeString = $( this ).attr( "title" ).split( "T" )[1];
      var d = new Date( Date.parse( $( elt ).attr( "title" ) ) );
      if ( !timeString.indexOf( ":" ) || typeof ( d ) !== "object" ) { return; }
      if ( now.getFullYear( ) === d.getFullYear( )
           && now.getMonth( ) === d.getMonth( )
           && now.getDate( ) === d.getDate( ) ) {
        return;
      }
      $( this ).html( monthNames[d.getMonth( )] + " " + d.getDate( ) );
    } );
  }

  $( "#subscribeModal" ).on( "show.bs.modal", function ( ) {
    var that = $( this );
    var taxonLabel = that.find( "#subscribeTaxonLabel" );
    var subscribeType = ( taxonLabel.css( "display" ) === "none" ) ? "place" : "taxon";
    var subscribeUrl = "/subscriptions/new?type=" + subscribeType
      + "&partial=form&authenticity_token=" + $( "meta[name=csrf-token]" ).attr( "content" );
    $.ajax( {
      url: subscribeUrl,
      cache: false,
      success: function ( html ) {
        that.find( ".modal-body" ).append( html );
      }
    } );
  } );

  $( "#subscribeModal" ).on( "hide.bs.modal", function ( ) {
    $( this ).find( ".modal-body" ).children( "form" ).remove( );
  } );

  $( "a[data-subscribe-type]" ).click( function ( ) {
    var subscribeType = $( this ).data( "subscribe-type" );
    if ( subscribeType === "taxon" ) {
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
  } );

  $( ".dashboard_tab" ).click( function ( ) {
    $( ".dashboard_tab" ).removeClass( "active" );
    $( this ).addClass( "active" );
  } );

  $( "#forum-topics" ).on( "show.bs.collapse", function ( ) {
    $( "#forum .panel-heading .pull-right i.fa" ).removeClass( "fa-caret-left" ).addClass( "fa-caret-down" );
    updateSession( { prefers_forum_topics_on_dashboard: true } );
  } );
  $( "#forum-topics" ).on( "hide.bs.collapse", function ( ) {
    $( "#forum .panel-heading .pull-right i.fa" ).removeClass( "fa-caret-down" ).addClass( "fa-caret-left" );
    updateSession( { prefers_forum_topics_on_dashboard: false } );
  } );

  $( "#close_needs_id_pilot_panel" ).on( "click", function ( e ) {
    e.preventDefault( );
    $( "#needs_id_pilot_panel" ).hide( );
    updateSession( { prefers_needs_id_pilot: false } );
  } );

  $( "#participate_button" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_needs_id_pilot: true } );
    $( "#participate_section" ).hide( );
    $( "#stop_participating_section" ).show( );
    $( "#close_needs_id_pilot_panel" ).hide( );
  } );

  $( "#stop_participating_link" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_needs_id_pilot: null } );
    $( "#stop_participating_section" ).hide( );
    $( "#participate_section" ).show( );
    $( "#close_needs_id_pilot_panel" ).show( );
  } );

  // gaps obs
  $( "#close_gaps_obs_pilot_panel" ).on( "click", function ( e ) {
    e.preventDefault( );
    $( "#gaps_obs_pilot_panel" ).hide( );
    updateSession( { prefers_gaps_obs_pilot: false } );
  } );

  $( "#gaps_obs_participate_button" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_gaps_obs_pilot: true } );
    $( "#gaps_obs_participate_section" ).hide( );
    $( "#gaps_obs_stop_participating_section" ).show( );
    $( "#close_gaps_obs_pilot_panel" ).hide( );
  } );

  $( "#gaps_obs_stop_participating_link" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_gaps_obs_pilot: null } );
    $( "#gaps_obs_stop_participating_section" ).hide( );
    $( "#gaps_obs_participate_section" ).show( );
    $( "#close_gaps_obs_pilot_panel" ).show( );
  } );

  // gaps id
  $( "#close_gaps_id_pilot_panel" ).on( "click", function ( e ) {
    e.preventDefault( );
    $( "#gaps_id_pilot_panel" ).hide( );
    updateSession( { prefers_gaps_id_pilot: false } );
  } );

  $( "#gaps_id_participate_button" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_gaps_id_pilot: true } );
    $( "#gaps_id_participate_section" ).hide( );
    $( "#gaps_id_stop_participating_section" ).show( );
    $( "#close_gaps_id_pilot_panel" ).hide( );
  } );

  $( "#gaps_id_stop_participating_link" ).on( "click", function ( e ) {
    e.preventDefault( );
    updateSession( { prefers_gaps_id_pilot: null } );
    $( "#gaps_id_stop_participating_section" ).hide( );
    $( "#gaps_id_participate_section" ).show( );
    $( "#close_gaps_id_pilot_panel" ).show( );
  } );
} );
