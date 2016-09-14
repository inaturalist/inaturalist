import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Glyphicon, OverlayTrigger, Tooltip } from "react-bootstrap";
import Photo from "./photo";

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
    let close;
    let item;
    let zoom;
    if ( this.props.file.preview && !this.props.file.photo ) {
      // preview photo
      item = ( <Photo { ...this.props } onClick={ this.openPhotoViewer } /> );
      zoom = this.zoomButton( );
      close = this.closeButton( );
    } else if ( this.props.file.photo ) {
      // uploaded photo
      item = ( <Photo { ...this.props } onClick={ this.openPhotoViewer } /> );
      zoom = this.zoomButton( );
      close = this.closeButton( );
    } else {
      // fallback state that is pretty much never seen
      item = ( <Glyphicon glyph="exclamation-sign" /> );
      close = this.closeButton( );
    }
    return (
      <div className="gallery-item">
        { close }
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
