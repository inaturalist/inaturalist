import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Glyphicon, Carousel } from "react-bootstrap";
import FileGalleryItem from "./file_gallery_item";

class FileGallery extends Component {

  render( ) {
    let content;
    const filesArray = _.values( this.props.obsCard.files );
    const count = filesArray.length;
    if ( count === 0 ) {
      content = (
        <div className="placeholder">
          <Glyphicon glyph="picture" />
        </div>
      );
    } else {
      content = (
        <Carousel
          ref="carousel"
          key={ `carousel${this.props.obsCard.id}${count}` }
          interval={ 0 }
          controls={ count > 1 }
          indicators={ false }
          onSlideEnd={ ( ) => this.props.updateObsCard( this.props.obsCard,
            { galleryIndex: this.refs.carousel.state.activeIndex + 1 } ) }
        >
          { _.map( _.sortBy( this.props.obsCard.files, "sort" ), f => (
            <Carousel.Item key={ `file${f.id}${count}` }>
              <FileGalleryItem
                obsCard={ this.props.obsCard }
                file={ f }
                setState={ this.props.setState }
                draggingProps={ this.props.draggingProps }
                confirmRemoveFile={ this.props.confirmRemoveFile }
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
