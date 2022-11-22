import PropTypes from "prop-types";
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
    if ( this.props.slideIndex && this.props.slideIndex > 0 ) {
      const that = this;
      setTimeout( ( ) => that.slideToSlideIndex( ), 500 );
    }
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.slideIndex !== prevProps.slideIndex ) {
      this.slideToSlideIndex( );
    }
    const domNode = ReactDOM.findDOMNode( this );
    if ( $( ".image-gallery-image > img", domNode ).length > 0 ) {
      this.setupEasyZoom( );
    }
  }

  setupEasyZoom( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const { items } = this.props;
    // Note that it's important to wrap the image with something so we can tell
    // when things have been set up for easyzoom and when they haven't
    const unzoomable = "<div class=\"unzoomable\"></div>";
    $( ".image-gallery-image > img", domNode ).wrap( function ( ) {
      const standardImgUrl = $( this ).attr( "src" );
      const image = items.find( i => ( i.original === standardImgUrl ) );
      if ( image ) {
        if (
          image.originalDimensions
          && (
            image.originalDimensions.width <= $( domNode ).width( )
            && image.originalDimensions.height <= $( domNode ).height( )
          )
        ) {
          return unzoomable;
        }
        return `<div class="easyzoom"><a href="${image.zoom || standardImgUrl}"></a></div>`;
      }
      return unzoomable;
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
    if ( _.isInteger( this.props.slideIndex ) ) {
      this.slideToIndex( this.props.slideIndex );
      // This forces the thumbnails container to translate to keep prev/next
      // thumbnails in view. Shouldn't be necessary but for some reason it
      // is.
      this._handleResize( );
    }
  }
}

ZoomableImageGallery.propTypes = Object.assign( { }, ImageGallery.propTypes, {
  slideIndex: PropTypes.number
} );

export default ZoomableImageGallery;
