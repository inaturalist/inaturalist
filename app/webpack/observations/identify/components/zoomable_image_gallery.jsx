import { PropTypes } from "react";
import ReactDOM from "react-dom";
import ImageGallery from "react-image-gallery";
import EasyZoom from "EasyZoom/dist/easyzoom";
import _ from "lodash";

class ZoomableImageGallery extends ImageGallery {

  componentDidMount() {
    super.componentDidMount( );
    const props = this.props;
    const domNode = ReactDOM.findDOMNode( this );
    $( ".image-gallery-slide img", domNode ).wrap( function ( ) {
      const standardImgUrl = $( this ).attr( "src" );
      const image = props.items.find( ( i ) => ( i.original === standardImgUrl ) );
      if ( image ) {
        return `<div class="easyzoom"><a href="${image.zoom || standardImgUrl}"></a></div>`;
      }
      return null;
    } );
    $( ".image-gallery-slide .easyzoom", domNode ).easyZoom( {
      eventType: "click",
      onShow( ) {
        this.$link.addClass( "easyzoom-zoomed" );
      },
      onHide( ) {
        this.$link.removeClass( "easyzoom-zoomed" );
      },
      loadingNotice: I18n.t( "loading" )
    } );
  }

  componentWillReceiveProps( newProps ) {
    if ( _.isInteger( newProps.currentIndex ) ) {
      this.slideToIndex( newProps.currentIndex );
    }
  }
}

ZoomableImageGallery.props = {
  currentIndex: PropTypes.number
};

export default ZoomableImageGallery;
