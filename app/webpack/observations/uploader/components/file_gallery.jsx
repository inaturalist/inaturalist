import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Glyphicon, Carousel } from "react-bootstrap";
import FileGalleryItem from "./file_gallery_item";

class FileGallery extends Component {
  render( ) {
    const {
      obsCard,
      setState,
      draggingProps,
      confirmRemoveFile,
      updateObsCard
    } = this.props;
    let content;
    const filesArray = _.values( obsCard.files );
    const count = filesArray.length;
    if ( count === 0 ) {
      const mediaValidationError = obsCard.validationErrors.media;
      content = (
        <div className={`placeholder${mediaValidationError ? " has-error" : ""}`}>
          <Glyphicon glyph="picture" />
        </div>
      );
    } else {
      content = (
        <Carousel
          ref="carousel"
          key={`carousel${obsCard.id}${count}`}
          interval={0}
          controls={count > 1}
          indicators={false}
          onSlideEnd={( ) => updateObsCard(
            obsCard,
            { galleryIndex: this.refs.carousel.state.activeIndex + 1 }
          )}
        >
          { _.map( _.sortBy( obsCard.files, "sort" ), f => (
            <Carousel.Item key={`file${f.id}${count}`}>
              <FileGalleryItem
                obsCard={obsCard}
                file={f}
                setState={setState}
                draggingProps={draggingProps}
                confirmRemoveFile={confirmRemoveFile}
              />
            </Carousel.Item>
          ) ) }
        </Carousel>
      );
    }
    return (
      <div className="img-container">
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
