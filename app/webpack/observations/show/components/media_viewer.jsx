import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
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
    $( "#lightboxBackdrop figure > img" ).wrap( function ( ) {
      let imgUrl = $( this ).attr( "src" );
      if ( $( this ).attr( "srcset" ) ) {
        const matches = $( this ).attr( "srcset" ).match( /^(.*?) / );
        imgUrl = matches[1];
      }
      return `<div class="easyzoom"><a href="${imgUrl}"></a></div>`;
    } );
    const easyZoomTarget = $( "#lightboxBackdrop .easyzoom" );
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
    $( "#lightboxBackdrop .easyzoom a" ).unbind( "click" );
    $( "#lightboxBackdrop .easyzoom a" ).on( "click", e => {
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
    let images = _.filter( this.props.observation.photos, p => !p.hidden ).map( photo => {
      let original = photo.photoUrl( "original" );
      let large = photo.photoUrl( "large" );
      let medium = photo.photoUrl( "medium" );
      if ( photo.flags && photo.flaggedAsCopyrighted( ) ) {
        original = SITE.copyrighted_media_image_urls.original;
        large = SITE.copyrighted_media_image_urls.large;
        medium = SITE.copyrighted_media_image_urls.medium;
      }
      if ( !photo.url && !photo.preview ) {
        original = SITE.processing_image_urls.small;
        large = SITE.processing_image_urls.small;
        medium = SITE.processing_image_urls.medium;
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
    // Note that adding a key here forces the lightbox to completely re-render
    // when switching to each new image, which is required for re-building the
    // easyzoom stuff for each image. Basically using that jQuery library with
    // react is really brittle. In a perfect world, zoom state would be an
    // expression of the component state or the props.
    return (
      <Lightbox
        key={ `lightbox-${this.props.mediaViewer.activeIndex}` }
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
