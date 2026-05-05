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

function hideFruButtons() {
  var container = document.querySelector( ".announcement" );
  var observer = new MutationObserver( function ( ) {
    var iframe = container.getElementsByTagName( "iframe" )[0];
    if ( !iframe || !iframe.contentDocument ) return;
    observer.disconnect( );
    var innerObserver = new MutationObserver( function ( ) {
      var renderContainer = iframe.contentDocument.getElementById( "render-container" );
      if ( !renderContainer ) return;
      var buttons = renderContainer.getElementsByClassName( "button" );
      if ( buttons.length > 1 ) {
        Array.from( buttons ).slice( 1 ).forEach( function ( button ) { button.style.display = "none"; } );
        innerObserver.disconnect( );
      }
    } );
    innerObserver.observe( iframe.contentDocument, { childList: true, subtree: true } );
  } );
  observer.observe( container, { childList: true, subtree: true } );
}
