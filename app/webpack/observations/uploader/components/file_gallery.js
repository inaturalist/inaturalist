import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Badge, Glyphicon, Carousel, CarouselItem } from "react-bootstrap";
import Photo from "./photo";

class FileGallery extends Component {

  constructor( props, context ) {
    super( props, context );
    this.openPhotoViewer = this.openPhotoViewer.bind( this );
  }

  openPhotoViewer( ) {
    this.props.setState( { photoViewer: {
      show: true,
      obsCard: this.props.obsCard,
      activeIndex: 0
    } } );
  }

  render( ) {
    let content;
    const filesArray = _.values( this.props.obsCard.files );
    const count = filesArray.length;
    // const galleryImages = _.reject( obsCard.files, f => !f.photo );
    const photoStates = _.invert( _.assign(
      _.chain( this.props.obsCard.files ).map( "upload_state" ).uniq( ).value( ) ) );
    let badgeText = filesArray.length > 0 ? filesArray.length : "";
    let badgeGlyph;
    if ( photoStates.uploading ) {
      badgeGlyph = ( <Glyphicon glyph="refresh" className="fa-spin" /> );
    } else if ( photoStates.pending ) {
      badgeGlyph = ( <Glyphicon glyph="hourglass" /> );
    }
    let badge = badgeText ? ( <Badge>{ badgeText } { badgeGlyph }</Badge> ) : "";
    if ( count === 0 ) {
      content = (
        <div className="placeholder">
          <Glyphicon glyph="picture" />
        </div>
      );
    } else {
      let zoom;
      if ( photoStates.uploaded ) {
        zoom = (
          <div className="zoom">
            <Badge onClick={ this.openPhotoViewer }>
              <Glyphicon glyph="zoom-in" />
            </Badge>
          </div>
        );
      }
      content = (
        <div>
          <Carousel
            ref="carousel"
            key={ `carousel${this.props.obsCard.id}${count}` }
            interval={ 0 }
            controls={ count > 1 }
            indicators={ count > 1 }
          >
            { _.map( this.props.obsCard.files, f => {
              let item;
              if ( f.upload_state === "uploading" ) {
                item = ( <Glyphicon glyph="refresh" className="fa-spin" /> );
              } else if ( f.upload_state === "pending" ) {
                item = ( <Glyphicon glyph="hourglass" /> );
              } else if ( f.photo ) {
                item = (
                  <Photo
                    obsCard={ this.props.obsCard }
                    file={ f }
                    src={ f.photo.large_url }
                    setState={ this.props.setState }
                    draggingProps={ this.props.draggingProps }
                    updateObsCard={ this.props.updateObsCard }
                    confirmRemoveFile={ this.props.confirmRemoveFile }
                  />
                );
              } else {
                item = ( <Glyphicon glyph="exclamation-sign" /> );
              }
              return ( <CarouselItem key={ `file${f.id}${count}` }>
                { item }
              </CarouselItem> );
            } ) }
          </Carousel>
          { zoom }
        </div>
      );
    }
    return (
      <div className="image">
        { badge }
        { content }
      </div>
    );
  }
}

FileGallery.propTypes = {
  obsCard: PropTypes.object,
  setState: PropTypes.func,
  draggingProps: PropTypes.object,
  updateObsCard: PropTypes.func,
  confirmRemoveFile: PropTypes.func
};

export default FileGallery;
