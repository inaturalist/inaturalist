import { PropTypes } from "react";
import _ from "lodash";
import ReactDOM from "react-dom";
import ImageGallery from "react-image-gallery";
import EasyZoom from "EasyZoom/dist/easyzoom";

class ZoomableImageGallery extends ImageGallery {

  componentDidMount( ) {
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
    const easyZoomTarget = $( ".image-gallery-slide .easyzoom", domNode );
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
    // close the zoomed image when mouse is out of the container
    easyZoomTarget.on( {
      "mouseleave.easyzoom touchend.easyzoom": () => {
        _.each( easyZoomTarget, t => {
          $( t ).data( "easyZoom" )._onLeave( );
        } );
      }
    } );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.slideIndex !== prevProps.slideIndex ) {
      this.slideToSlideIndex( );
    }
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
