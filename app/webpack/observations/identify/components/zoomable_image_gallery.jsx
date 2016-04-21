import ReactDOM from "react-dom";
import ImageGallery from "react-image-gallery";
import EasyZoom from "EasyZoom/dist/easyzoom";

class ZoomableImageGallery extends ImageGallery {
  componentDidMount() {
    super.componentDidMount( );
    const domNode = ReactDOM.findDOMNode( this );
    $( ".image-gallery-slide img", domNode ).wrap( function ( ) {
      const standardImgUrl = $( this ).attr( "src" );
      return `<div class="easyzoom"><a href="${standardImgUrl}"></a></div>`;
    } );
    $( ".image-gallery-slide .easyzoom", domNode ).easyZoom( {
      onShow( ) {
        this.$link.addClass( "easyzoom-zoomed" );
      },
      onHide( ) {
        this.$link.removeClass( "easyzoom-zoomed" );
      }
    } );
  }
}

export default ZoomableImageGallery;
