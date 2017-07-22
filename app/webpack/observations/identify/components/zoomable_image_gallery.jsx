import { PropTypes } from "react";
import _ from "lodash";
import ReactDOM from "react-dom";
import ImageGallery from "react-image-gallery";
import EasyZoom from "EasyZoom/dist/easyzoom";

class ZoomableImageGallery extends ImageGallery {

  constructor( props ) {
    super( props );
    this.setupEasyZoom = this.setupEasyZoom.bind( this );
  }

  componentDidMount( ) {
    super.componentDidMount( );
    this.setupEasyZoom( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.slideIndex !== prevProps.slideIndex ) {
      this.slideToSlideIndex( );
      this.setupEasyZoom( );
    }
  }

  setupEasyZoom( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const items = this.props.items;
    $( ".image-gallery-image > img", domNode ).wrap( function ( ) {
      const standardImgUrl = $( this ).attr( "src" );
      const image = items.find( ( i ) => ( i.original === standardImgUrl ) );
      if ( image ) {
        return `<div class="easyzoom"><a href="${image.zoom || standardImgUrl}"></a></div>`;
      }
      return null;
    } );
    const easyZoomTarget = $( ".image-gallery-image .easyzoom", domNode );
    easyZoomTarget.easyZoom( {
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

  slideToSlideIndex( ) {
    if (
      _.isInteger( this.props.slideIndex )
    ) {
      this.slideToIndex( this.props.slideIndex );
    }
  }
}

ZoomableImageGallery.propTypes = Object.assign( { }, ImageGallery.propTypes, {
  slideIndex: PropTypes.number
} );

export default ZoomableImageGallery;
