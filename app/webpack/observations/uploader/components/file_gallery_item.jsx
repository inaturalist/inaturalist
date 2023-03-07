import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Glyphicon, OverlayTrigger, Tooltip } from "react-bootstrap";
import Photo from "./photo";
import Sound from "./sound";

class FileGalleryItem extends Component {

  constructor( props, context ) {
    super( props, context );
    this.openPhotoViewer = this.openPhotoViewer.bind( this );
    this.closeButton = this.closeButton.bind( this );
    this.zoomButton = this.zoomButton.bind( this );
  }

  openPhotoViewer( ) {
    const photoIndex = _.indexOf( this.props.obsCard.uploadedFileIDs(), this.props.file.id );
    this.props.setState( { photoViewer: {
      show: true,
      obsCard: this.props.obsCard,
      activeIndex: ( photoIndex === -1 ) ? 0 : photoIndex
    } } );
  }

  closeButton( ) {
    return (
      <OverlayTrigger
        placement="top"
        delayShow={ 1000 }
        overlay={ ( <Tooltip id="remove-photo-tip">{
          I18n.t( "uploader.tooltips.remove_photo" ) }</Tooltip> ) }
      >
        <button className="btn-close-photo" onClick={ () =>
          this.props.confirmRemoveFile( this.props.file ) }
        >
          <Glyphicon glyph="remove" />
        </button>
      </OverlayTrigger>
    );
  }

  zoomButton( ) {
    return (
      <button className="btn-enlarge" onClick={ this.openPhotoViewer }>
        <Glyphicon glyph="search" />
      </button>
    );
  }

  render( ) {
    let item;
    let zoom;
    let closeButton;
    const { file } = this.props;
    const previewAvailable = ( file.preview && !file.photo );
    const photoAvailable = ( file.photo && file.uploadState !== "failed" );
    // const soundAvailable = ( file.sound && file.uploadState !== "failed" );
    const uploadFailed = ( file.uploadState === "failed" );
    const isSound = file.type.match( /audio/ );
    if ( !uploadFailed && isSound ) {
      item = ( <Sound {...this.props} /> );
    } else if ( !uploadFailed && ( previewAvailable || photoAvailable ) ) {
      // preview photo
      item = ( <Photo {...this.props} onClick={this.openPhotoViewer} /> );
      zoom = this.zoomButton( );
      closeButton = this.closeButton( );
    } else {
      item = (
        <div className="failed">
          <OverlayTrigger
            placement="top"
            delayShow={1000}
            overlay={(
              <Tooltip id="merge-tip">{ I18n.t( "uploader.tooltips.upload_failed" ) }</Tooltip>
            )}
          >
            <Glyphicon glyph="exclamation-sign" />
          </OverlayTrigger>
          <div className="text-muted">
            { file.name }
          </div>
        </div>
      );
    }
    return (
      <div className="gallery-item">
        { closeButton }
        { item }
        { zoom }
      </div>
    );
  }
}

FileGalleryItem.propTypes = {
  obsCard: PropTypes.object,
  file: PropTypes.object,
  setState: PropTypes.func,
  confirmRemoveFile: PropTypes.func,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func,
  connectDragPreview: PropTypes.func
};

export default FileGalleryItem;
