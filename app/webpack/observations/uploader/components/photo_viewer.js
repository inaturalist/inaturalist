import _ from "lodash";
import React, { PropTypes, Component } from "react";
import Lightbox from "react-images";

class PhotoViewer extends Component {

  constructor( props, context ) {
    super( props, context );
    this.close = this.close.bind( this );
    this.next = this.next.bind( this );
    this.prev = this.prev.bind( this );
  }

  close( ) {
    this.props.updateState( { photoViewer: { show: false } } );
  }

  next( ) {
    this.props.updateState( { photoViewer: { activeIndex: this.props.activeIndex + 1 } } );
  }

  prev( ) {
    this.props.updateState( { photoViewer: { activeIndex: this.props.activeIndex - 1 } } );
  }

  render( ) {
    let images = [];
    if ( this.props.obsCard ) {
      images = _.map( this.props.obsCard.files, f => (
        { src: f.photo ? f.photo.large_url : f.file.preview } ) );
    }
    return (
      <Lightbox
        onClickPrev={ this.prev }
        onClickNext={ this.next }
        isOpen={ this.props.show }
        currentImage={ this.props.activeIndex }
        onClose={ this.close }
        images={ images }
        backdropClosesModal
      />
    );
  }
}

PhotoViewer.propTypes = {
  show: PropTypes.bool,
  obsCard: PropTypes.object,
  activeIndex: PropTypes.number,
  updateState: PropTypes.func
};

export default PhotoViewer;
