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
