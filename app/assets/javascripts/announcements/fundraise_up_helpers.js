function loadFundraiseUpWidget( ) {
  (function( w, d, s, n, a ) {
    if ( !w[n] ) {
      var l = "call,catch,on,once,set,then,track,openCheckout"
        .split( "," ), i, o = function( n ) {
          return "function" == typeof n ? o.l.push( [arguments] ) && o
            : function( ) { return o.l.push( [n, arguments] ) && o };
        }, t = d.getElementsByTagName( s )[0],
        j = d.createElement( s );
      j.async = !0;
      j.src = "https://cdn.fundraiseup.com/widget/" + a + "";
      t.parentNode.insertBefore( j, t );
      o.s = Date.now( );
      o.v = 5;
      o.h = w.location.href;
      o.l = [];
      for ( i = 0; i < 8; i++ ) o[l[i]] = o( l[i] );
      w[n] = o;
    }
  })( window, document, "script", "FundraiseUp", "ACSSCSPN" );
}

function initAnnouncementDismiss( announcementId ) {
  var announcementRoot = document.getElementById( announcementId );
  if ( !announcementRoot ) return;
  $( announcementRoot ).find( "form" ).on( "submit", function( e ) {
    e.preventDefault( );
    $( announcementRoot ).fadeOut( );
    $.ajax( {
      type: "PUT",
      url: $( this ).attr( "action" )
    } );
  } );
}

function initFruFallback( announcementId ) {
  var root = document.getElementById( announcementId );
  if ( !root ) return;
  var fallback = root.querySelector( ".fru-fallback" );
  var fruAnchor = root.querySelector( "a[href^=\"#\"][style*=\"display\"]" );
  if ( fallback && fruAnchor ) {
    fruAnchor.parentNode.insertBefore( fallback, fruAnchor.nextSibling );
  }
  var observer = new MutationObserver( function ( ) {
    if ( root.querySelector( "iframe" ) ) {
      fallback.style.display = "none";
      observer.disconnect( );
    }
  } );
  observer.observe( root, { childList: true, subtree: true } );
}

function initDonateFruFallback( containerSelector ) {
  var container = document.querySelector( containerSelector );
  if ( !container ) return;
  var fallback = container.querySelector( ".fru-fallback" );
  if ( !fallback ) return;
  var observer = new MutationObserver( function( ) {
    if ( container.querySelector( "iframe" ) ) {
      fallback.style.display = "none";
      observer.disconnect( );
    }
  } );
  observer.observe( container, { childList: true, subtree: true } );
}
