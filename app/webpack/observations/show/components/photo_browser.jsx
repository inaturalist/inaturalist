import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import {
  Badge,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import ImageGallery from "react-image-gallery";
import Dropzone from "react-dropzone";
import ObservationPhotoAttribution from "../../../shared/components/observation_photo_attribution";
import HiddenContentMessageContainer from "../../../shared/containers/hidden_content_message_container";
import { ACCEPTED_FILE_TYPES, MAX_FILE_SIZE } from "../../uploader/models/util";

const soundIcon = "data:image/png;base64,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";

class PhotoBrowser extends React.Component {
  constructor( ) {
    super( );
    this.addPhotoButton = this.addPhotoButton.bind( this );
    this.state = {
      slideIndex: 0
    };
  }

  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    // move the add-photo button into the thumbnail list
    $( ".add-photo", domNode ).appendTo( ".image-gallery-thumbnails-container", domNode );

    // Remove the button role from slides that contain audio. This seems to
    // actually cause Voice Over in Safari to ignore the audio controls
    // inside of the button
    $( ".image-gallery-slide", domNode ).each( ( slideIndex, slide ) => {
      if ( $( "audio", slide ).length > 0 ) {
        $( slide ).attr( "role", null );
      }
    } );
  }

  componentDidUpdate( prevProps ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".add-photo", domNode ).appendTo( ".image-gallery-thumbnails-container", domNode );
    const { observation } = this.props;
    const prevObservationID = prevProps.observation ? prevProps.observation.id : null;
    const currObservationID = observation ? observation.id : null;
    if ( prevObservationID !== currObservationID ) {
      // ensure the image gallery is reset to the first item when the observation changes
      this.resetSlideIndex( );
    }
  }

  resetSlideIndex( ) {
    this.setState( { slideIndex: 0 } );
  }

  attributionIcon( media, type ) {
    const { observation } = this.props;
    return (
      <OverlayTrigger
        container={$( "#wrapper.bootstrap" ).get( 0 )}
        placement="top"
        delayShow={500}
        trigger="click"
        rootClose
        overlay={(
          <Tooltip id="add-tip">
            <ObservationPhotoAttribution photo={media} observation={observation} />
          </Tooltip>
        )}
        key={`${type}-${media.id}-license`}
      >
        { media.license_code && media.license_code !== "C" ? (
          <i className="fa fa-creative-commons license" />
        ) : (
          <i className="fa fa-copyright license" />
        ) }
      </OverlayTrigger>
    );
  }

  addPhotoButton( ) {
    if ( !this.viewerIsObserver ) { return null; }
    // the wrapping <span>, which is not moved,
    // causes a react reload failure to go away
    return (
      <span className="add-photo-span">
        <button
          type="button"
          className="add-photo image-gallery-thumbnail btn btn-nostyle"
          onClick={( ) => this.refs.dropzone.open( )}
        >
          <i className="fa fa-picture-o" />
          <i className="fa fa-plus" />
        </button>
      </span>
    );
  }

  render( ) {
    const {
      config,
      observation,
      onFileDrop,
      setFlaggingModalState,
      hideContent,
      unhideContent,
      revealHiddenContent,
      setMediaViewerState
    } = this.props;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    this.viewerIsObserver = config && config.currentUser
      && config.currentUser.id === observation.user.id;
    const viewerIsCurator = config && config.currentUser && (
      config.currentUser.roles.indexOf( "curator" ) >= 0
      || config.currentUser.roles.indexOf( "admin" ) >= 0
    );
    const viewerIsAdmin = config && config.currentUser && (
      config.currentUser.roles.indexOf( "admin" ) >= 0
    );
    let mediaViewerIndex = 0;
    const images = observation.photos.map( photo => {
      if ( photo.api_status === "processing" ) {
        return {
          loading: true
        };
      }
      // extend photo to have a user property, but preserve its constructor type
      photo = new photo.constructor( { ...photo, user: observation.user } );
      let original = photo.photoUrl( "original" );
      let large = photo.photoUrl( "large" );
      let square = photo.photoUrl( "square" );
      if ( photo.flags && photo.flaggedAsCopyrighted( ) ) {
        ( { original, large, square } = SITE.copyrighted_media_image_urls );
      }

      if ( !photo.url && !photo.preview ) {
        original = SITE.processing_image_urls.small;
        large = SITE.processing_image_urls.small;
        ( { square } = SITE.processing_image_urls );
      } else if ( !photo.url ) {
        square = null;
      }
      let description;
      if ( photo.id ) {
        description = (
          <div className="captions">
            <div className="captions-box">
              { this.attributionIcon( photo, "photo" ) }
              <button
                type="button"
                className="btn btn-nostyle"
                onClick={( ) => setFlaggingModalState( {
                  item: photo,
                  show: true,
                  radioOptions: ["spam", "copyright infringement", "inappropriate"]
                } )}
                title={I18n.t( "flag_as_inappropriate" )}
              >
                <i className="fa fa-flag" />
              </button>
              { // observers never see hiding, curators do if its unhidden, admins always do
                ( !this.viewerIsObserver && (
                  ( !photo.hidden && viewerIsCurator )
                  || ( photo.hidden && viewerIsAdmin )
                ) ) && (
                <button
                  type="button"
                  className="btn btn-nostyle"
                  onClick={( ) => ( photo.hidden
                    ? unhideContent( photo )
                    : hideContent( photo )
                  )}
                  title={photo.hidden
                    ? I18n.t( "unhide_content" )
                    : I18n.t( "hide_content" )}
                >
                  <i className={`fa ${photo.hidden ? "fa-eye" : "fa-eye-slash"}`} />
                </button>
                )
              }
              <a href={`/photos/${photo.id}`}>
                <Badge>
                  <i className="fa fa-info" />
                </Badge>
              </a>
            </div>
          </div>
        );
      }
      if ( photo.hidden ) {
        const overlay = (
          <HiddenContentMessageContainer
            item={photo}
            itemType="photos"
            itemIDField="id"
          />
        );
        return {
          original: null,
          zoom: null,
          thumbnail: square,
          description: (
            <div className="hidden-media">
              {overlay}
              { ( viewerIsCurator || this.viewerIsObserver ) && (
                <button
                  type="button"
                  className="btn btn-default btn-xs reveal-hidden"
                  onClick={( ) => revealHiddenContent( photo )}
                >
                  { I18n.t( "show_hidden_content" ) }
                </button>
              ) }
              {description}
            </div>
          )
        };
      }
      const slideDetails = {
        original: large,
        zoom: original,
        thumbnail: square,
        mediaViewerIndex,
        description
      };
      mediaViewerIndex += 1;
      return slideDetails;
    } );
    _.each( observation.sounds, sound => {
      if ( sound.api_status === "processing" ) {
        images.push( {
          loading: true
        } );
        return;
      }
      // extend sound to have a user property, but preserve its constructor type
      sound = new sound.constructor( { ...sound, user: observation.user } );
      let player;
      let containerClass = "sound-container-local";
      let flagNotice;
      if ( _.find( sound.flags, f => !f.resolved ) ) {
        flagNotice = (
          <p className="flag-notice alert alert-warning">
            { I18n.t( "sounds.sound_has_been_flagged" )}
            { " " }
            <a href={`/sounds/${sound.id}/flags`} className="linky">
              { I18n.t( "view_flags" ) }
            </a>
          </p>
        );
      }
      if ( sound.hidden ) {
        const overlay = (
          <HiddenContentMessageContainer
            item={sound}
            itemType="sounds"
            itemIDField="id"
          />
        );
        player = (
          <div className="hidden-media">
            {overlay}
            { ( viewerIsCurator || this.viewerIsObserver ) && (
              <button
                type="button"
                className="btn btn-default btn-xs reveal-hidden"
                onClick={( ) => revealHiddenContent( sound )}
              >
                { I18n.t( "show_hidden_content" ) }
              </button>
            ) }
          </div>
        );
      } else if ( !sound.play_local && ( sound.subtype === "SoundcloudSound" || !sound.file_url ) ) {
        containerClass = "sound-container-soundcloud";
        player = (
          <iframe
            title="Soundcloud"
            scrolling="no"
            frameBorder="no"
            src={
              `https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F${sound.native_sound_id}&show_artwork=false&secret_token=${sound.secret_token}`
            }
          />
        );
      } else {
        player = (
          <audio controls preload="none" controlsList="nodownload">
            <source src={sound.file_url} type={sound.file_content_type} />
            { I18n.t( "your_browser_does_not_support_the_audio_element" ) }
          </audio>
        );
      }
      let playerContent = player;
      if ( flagNotice ) {
        if ( this.viewerIsObserver || viewerIsCurator ) {
          playerContent = (
            <div>
              { flagNotice }
              { player }
            </div>
          );
        } else {
          playerContent = flagNotice;
        }
      }
      images.push( {
        original: null,
        zoom: null,
        thumbnail: soundIcon,
        description: (
          <div className={`sound-container ${containerClass}`}>
            <div className="sound">
              { playerContent }
            </div>
            <div className="captions">
              <div className="captions-box">
                { this.attributionIcon( sound, "sound" ) }
                { " " }
                <button
                  type="button"
                  className="btn btn-nostyle"
                  onClick={( ) => setFlaggingModalState( {
                    item: sound,
                    show: true,
                    radioOptions: ["spam", "copyright infringement", "inappropriate"]
                  } )}
                  title={I18n.t( "flag_this_sound" )}
                >
                  <i className="fa fa-flag" />
                </button>
                { // observers never see hiding, curators do if its unhidden, admins always do
                  ( !this.viewerIsObserver && (
                    ( !sound.hidden && viewerIsCurator )
                    || ( sound.hidden && viewerIsAdmin )
                  ) ) && (
                  <button
                    type="button"
                    className="btn btn-nostyle"
                    onClick={( ) => ( sound.hidden
                      ? unhideContent( sound )
                      : hideContent( sound )
                    )}
                    title={sound.hidden
                      ? I18n.t( "unhide_content" )
                      : I18n.t( "hide_content" )}
                  >
                    <i className={`fa ${sound.hidden ? "fa-eye" : "fa-eye-slash"}`} />
                  </button>
                  )
                }
              </div>
            </div>
          </div>
        )
      } );
    } );

    let contents;
    let showThumbnails;
    if ( _.isEmpty( images ) ) {
      const iconicTaxonName = observation.taxon && observation.taxon.iconic_taxon_name
        ? observation.taxon.iconic_taxon_name.toLowerCase( )
        : "unknown";
      contents = (
        <div>
          <i className={`fa icon-iconic-${iconicTaxonName}`} />
          <span className="nophoto">{ I18n.t( "no_photo" ) }</span>
          { this.addPhotoButton( ) }
        </div>
      );
    } else {
      showThumbnails = this.viewerIsObserver ? true : images.length > 1;
      contents = (
        <ImageGallery
          key={`media-for-${observation.id}`}
          ref="gallery"
          items={images}
          showThumbnails={showThumbnails}
          lazyLoad={false}
          disableArrowKeys
          showNav={false}
          showFullscreenButton={false}
          showPlayButton={false}
          slideDuration={0}
          startIndex={this.state.slideIndex}
          renderCustomControls={this.addPhotoButton}
          onClick={e => {
            if ( !$( e.target ).is( "img" ) ) { return; }
            const index = this.refs.gallery.state.currentIndex;
            if ( _.has( images[index], "mediaViewerIndex" ) ) {
              setMediaViewerState( {
                show: true,
                activeIndex: images[index].mediaViewerIndex
              } );
            }
          }}
          onSlide={currentIndex => {
            this.state.slideIndex = currentIndex;
            if ( _.has( images[currentIndex], "mediaViewerIndex" ) ) {
              setMediaViewerState( { activeIndex: images[currentIndex].mediaViewerIndex } );
            }
            $( ".PhotoBrowser audio" ).each( ( i, elt ) => {
              elt.pause( );
            } );
          }}
          // this is the standard renderItem, minus some attributes and adding draggable="false"
          renderItem={item => (
            <div className="image-gallery-image">
              { item.imageSet && (
                <picture>
                  {
                    item.imageSet.map( ( source, index ) => (
                      <source
                        key={index}
                        media={source.media}
                        srcSet={source.srcSet}
                        type={source.type}
                      />
                    ) )
                  }
                  <img
                    alt={item.originalAlt}
                    src={item.original}
                  />
                </picture>
              ) }
              { !item.imageSet && item.original && (
                <img
                  src={item.original}
                  alt={item.originalAlt}
                  srcSet={item.srcSet}
                  sizes={item.sizes}
                  title={item.originalTitle}
                  draggable="false"
                />
              ) }

              {
                item.description && (
                  <span className="image-gallery-description">
                    {item.description}
                  </span>
                )
              }
              { item.loading && ( <div className="loading_spinner" /> ) }
            </div>
          )}
          renderThumbInner={item => {
            if ( !item.thumbnail ) {
              return ( <div className="loading_spinner" /> );
            }
            return (
              <div className="image-gallery-thumbnail-inner">
                <img
                  draggable={false}
                  src={item.thumbnail}
                  alt={item.thumbnailAlt}
                  title={item.thumbnailTitle}
                />
                <div className="image-gallery-thumbnail-label">
                  {item.thumbnailLabel}
                </div>
              </div>
            );
          }}
        />
      );
    }
    const browserClasses = [];
    if ( _.isEmpty( images ) ) { browserClasses.push( "empty" ); }
    if ( !showThumbnails ) { browserClasses.push( "no-thumbs" ); }
    const browser = (
      <div className={`PhotoBrowser ${browserClasses.join( " " )}`}>
        { contents }
      </div>
    );
    if ( this.viewerIsObserver ) {
      return (
        <Dropzone
          ref="dropzone"
          className={`dropzone ${_.isEmpty( images ) ? "empty" : ""}`}
          onDrop={( acceptedFiles, rejectedFiles, dropEvent ) => {
            // trying to protect against treating images dragged from the
            // same page from being treated as new files. Images dragged from
            // the same page will appear as multiple dataTransferItems, the
            // first being a "string" kind and not a "file" kind
            if ( dropEvent.nativeEvent.dataTransfer
              && dropEvent.nativeEvent.dataTransfer.items
              && dropEvent.nativeEvent.dataTransfer.items.length > 0
              && dropEvent.nativeEvent.dataTransfer.items[0].kind === "string" ) {
              return;
            }
            _.each( acceptedFiles, file => {
              try {
                file.preview = file.preview || window.URL.createObjectURL( file );
              } catch ( err ) {
                // eslint-disable-next-line no-console
                console.error( "Failed to generate preview for file", file, err );
              }
            } );
            onFileDrop( acceptedFiles, rejectedFiles, dropEvent );
          }}
          activeClassName="hover"
          disableClick
          disablePreview
          accept={ACCEPTED_FILE_TYPES}
          maxSize={MAX_FILE_SIZE}
        >
          { browser }
          <div className="hover-drop">
            { I18n.t( "drop_it" ) }
          </div>
        </Dropzone>
      );
    }
    return browser;
  }
}

PhotoBrowser.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  setMediaViewerState: PropTypes.func,
  onFileDrop: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  hideContent: PropTypes.func,
  unhideContent: PropTypes.func,
  revealHiddenContent: PropTypes.func
};

export default PhotoBrowser;
