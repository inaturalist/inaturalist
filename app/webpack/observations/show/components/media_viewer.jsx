import React, { PropTypes, Component } from "react";
import Lightbox from "react-images";
import EasyZoom from "EasyZoom/dist/easyzoom";
/* global SITE */

class MediaViewer extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.next = this.next.bind( this );
    this.prev = this.prev.bind( this );
  }

  componentDidMount( ) {
    setTimeout( ( ) => { this.easyzoom( ); }, 200 );
  }

  componentDidUpdate( ) {
    setTimeout( ( ) => { this.easyzoom( ); }, 200 );
  }

  easyzoom( ) {
    $( "#react-images-container .content--jss-0-1 img" ).wrap( function ( ) {
      let imgUrl = $( this ).attr( "src" );
      if ( $( this ).attr( "srcset" ) ) {
        const matches = $( this ).attr( "srcset" ).match( /^(.*?) / );
        imgUrl = matches[1];
      }
      return `<div class="easyzoom"><a href="${imgUrl}"></a></div>`;
    } );
    const easyZoomTarget = $( "#react-images-container .easyzoom" );
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
    $( "#react-images-container .easyzoom a" ).unbind( "click" );
    $( "#react-images-container .easyzoom a" ).on( "click", e => {
      if ( !$( e.target ).is( "img" ) ) {
        this.close( );
      }
    } );
  }

  close( ) {
    this.props.setMediaViewerState( { show: false } );
  }

  next( ) {
    this.props.setMediaViewerState( {
      activeIndex: ( this.props.mediaViewer.activeIndex || 0 ) + 1 } );
  }

  prev( ) {
    this.props.setMediaViewerState( {
      activeIndex: ( this.props.mediaViewer.activeIndex || 0 ) - 1
    } );
  }

  render( ) {
    const { observation } = this.props;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    let images = this.props.observation.photos.map( photo => {
      let original = photo.photoUrl( "original" );
      let large = photo.photoUrl( "large" );
      let medium = photo.photoUrl( "medium" );
      if ( photo.flaggedAsCopyrighted( ) ) {
        original = SITE.copyrighted_media_image_urls.original;
        large = SITE.copyrighted_media_image_urls.large;
        medium = SITE.copyrighted_media_image_urls.medium;
      }
      return {
        src: large,
        srcset: [
          `${original} 2048w`,
          `${large} 1024w`,
          `${medium} 200w`
        ]
      };
    } );
    return (
      <Lightbox
        ref="lightbox"
        onClickPrev={ this.prev }
        onClickNext={ this.next }
        isOpen={ this.props.mediaViewer.show }
        currentImage={ this.props.mediaViewer.activeIndex }
        onClose={ this.close }
        onClickShowNextImage={ false }
        showImageCount={ false }
        images={ images }
        backdropClosesModal
        width={ 5000 }
      />
    );
  }
}

MediaViewer.propTypes = {
  observation: PropTypes.object,
  mediaViewer: PropTypes.object,
  setMediaViewerState: PropTypes.func
};

export default MediaViewer;
