if ( window.FundraiseUp ) {
  FundraiseUp.catch( function ( e ) {
    if ( window.iNaturalist ) iNaturalist.logError( e );
  } );
}

function hideFruButtons() {
  var container = document.querySelector( ".announcement" );
  if ( !container ) {
    if ( window.iNaturalist ) iNaturalist.log( { "fru-embed": "no-announcement-container" } );
    return;
  }
  var observer = new MutationObserver( function ( ) {
    try {
      var iframe = container.getElementsByTagName( "iframe" )[0];
      if ( !iframe || !iframe.contentDocument ) return;
      observer.disconnect( );
      var innerObserver = new MutationObserver( function ( ) {
        try {
          var renderContainer = iframe.contentDocument.getElementById( "render-container" );
          if ( !renderContainer ) return;
          var buttons = renderContainer.getElementsByClassName( "button" );
          if ( buttons.length > 1 ) {
            Array.from( buttons ).slice( 1 ).forEach( function ( button ) { button.style.display = "none"; } );
            innerObserver.disconnect( );
          }
        } catch ( e ) {
          if ( window.iNaturalist ) iNaturalist.logError( e );
          innerObserver.disconnect( );
        }
      } );
      innerObserver.observe( iframe.contentDocument, { childList: true, subtree: true } );
    } catch ( e ) {
      if ( window.iNaturalist ) iNaturalist.logError( e );
      observer.disconnect( );
    }
  } );
  observer.observe( container, { childList: true, subtree: true } );
}
