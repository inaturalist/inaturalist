import React, { PropTypes, Component } from "react";
import Lightbox from "react-images";
/* global SITE */

class MediaViewer extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.next = this.next.bind( this );
    this.prev = this.prev.bind( this );
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
