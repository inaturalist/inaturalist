import ReactDOMServer from "react-dom/server";

const definePopupClass = ( ) => {
  /**
   * A customized popup on the map.
   * @param {!google.maps.LatLng} position
   * @param {!Element} content
   * @constructor
   * @extends {google.maps.OverlayView}
   */
  const Popup = function ( position, color, c ) {
    this.position = position;

    const content = document.createElement( "div" );
    content.classList.add( "popup-bubble-content" );
    content.innerHTML = ReactDOMServer.renderToString( c );

    const pixelOffset = document.createElement( "div" );
    pixelOffset.classList.add( "popup-bubble-anchor" );
    pixelOffset.appendChild( content );

    this.anchor = document.createElement( "div" );
    this.anchor.classList.add( "popup-tip-anchor" );
    this.anchor.appendChild( pixelOffset );
    this.anchor.style.background = color;
    this.anchor.style["border-color"] = color;

    // Optionally stop clicks, etc., from bubbling up to the map.
    this.stopEventPropagation();
  };
  // NOTE: google.maps.OverlayView is only defined once the Maps API has
  // loaded. That is why Popup is defined inside initMap().
  if ( typeof ( google ) !== "undefined" ) {
    Popup.prototype = Object.create( google.maps.OverlayView.prototype );
  }

  /** Called when the popup is added to the map. */
  Popup.prototype.onAdd = function ( ) {
    this.getPanes().overlayMouseTarget.appendChild( this.anchor );
  };

  /** Called when the popup is removed from the map. */
  Popup.prototype.onRemove = function ( ) {
    if ( this.anchor.parentElement ) {
      this.anchor.parentElement.removeChild( this.anchor );
    }
  };

  /** Called when the popup needs to draw itself. */
  Popup.prototype.draw = function ( ) {
    const divPosition = this.getProjection().fromLatLngToDivPixel( this.position );
    // Hide the popup when it is far out of view.
    const display = Math.abs( divPosition.x ) < 4000 && Math.abs( divPosition.y ) < 4000
      ? "block"
      : "none";

    if ( display === "block" ) {
      this.anchor.style.left = divPosition.x + "px";
      this.anchor.style.top = divPosition.y + "px";
    }
    if ( this.anchor.style.display !== display ) {
      this.anchor.style.display = display;
    }
  };

  /** Stops clicks/drags from bubbling up to the map. */
  Popup.prototype.stopEventPropagation = function( ) {
    const anchor = this.anchor;
    anchor.style.cursor = "auto";

    ["click", "dblclick", "contextmenu", "wheel", "mousedown", "touchstart",
     "pointerdown"]
        .forEach( function( event ) {
          anchor.addEventListener( event, function( e ) {
            e.stopPropagation( );
          } );
        } );
  };
  return Popup;
};

export {
  definePopupClass
};
