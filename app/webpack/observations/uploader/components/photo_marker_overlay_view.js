export default class PhotoMarkerOverlayView extends google.maps.OverlayView {
  constructor( imgUrl, latLng ) {
    super( );
    console.log( "[DEBUG] PhotoMarkerOverlayView constructor, imgUrl: ", imgUrl, ", latLng: ", latLng );
    this.imgUrl = imgUrl;
    this.latLng = latLng;
  }

  onAdd( ) {
    this.div = document.createElement( "div" );
    this.div.style.position = "absolute";
    this.div.classList.add( "photo-marker" );
    const img = document.createElement( "img" );
    img.src = this.imgUrl;
    this.div.appendChild( img );
    this.getPanes( ).overlayLayer.appendChild( this.div );
  }

  draw( ) {
    console.log( "[DEBUG] PhotoMarkerOverlayView draw, this.imgUrl: ", this.imgUrl, ", this.latLng: ", this.latLng );
    const point = this.getProjection( ).fromLatLngToDivPixel( this.latLng );
    if ( this.div ) {
      this.div.style.left = `${point.x}px`;
      this.div.style.top = `${point.y}px`;
    }
  }

  onRemove() {
    if ( this.div ) {
      this.div.parentNode.removeChild( this.div );
      delete this.div;
    }
  }
}
