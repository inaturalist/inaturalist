function initFruFallback( containerSelector ) {
  var container = document.querySelector( containerSelector );
  if ( !container ) return;
  var fallback = container.querySelector( ".fru-fallback" );
  if ( !fallback ) return;
  var fruAnchor = container.querySelector( "a[href^=\"#\"][style*=\"display\"]" );
  if ( fruAnchor ) {
    fruAnchor.parentNode.insertBefore( fallback, fruAnchor.nextSibling );
  }
  var observer = new MutationObserver( function( ) {
    if ( container.querySelector( "iframe" ) ) {
      fallback.style.display = "none";
      observer.disconnect( );
    }
  } );
  observer.observe( container, { childList: true, subtree: true } );
}
