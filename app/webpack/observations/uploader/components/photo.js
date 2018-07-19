import React, { Component } from "react";
import PropTypes from "prop-types";
import { DragSource } from "react-dnd";
import { pipe } from "ramda";

const photoSource = {
  beginDrag( props ) {
    props.setState( { draggingProps: props } );
    return props;
  },
  endDrag( props ) {
    props.setState( { draggingProps: null } );
    return props;
  }
};

class Photo extends Component {

  static collect( connect, monitor ) {
    return {
      connectDragSource: connect.dragSource( ),
      isDragging: monitor.isDragging( ),
      connectDragPreview: connect.dragPreview( )
    };
  }

  render( ) {
    let className = "photoDrag";
    if ( this.props.draggingProps &&
         this.props.draggingProps.file &&
         this.props.draggingProps.file.id === this.props.file.id ) {
      className += " drag";
    }
    return (
      <div>
        { this.props.connectDragSource(
          <div className={ className }>
            <img
              className="img-thumbnail"
              src={ this.props.file.photo ?
                this.props.file.photo.large_url : this.props.file.preview }
              onClick={ this.props.onClick }
            />
          </div>
        ) }
      </div>
    );
  }
}

Photo.propTypes = {
  src: PropTypes.string,
  obsCard: PropTypes.object,
  file: PropTypes.object,
  onClick: PropTypes.func,
  setState: PropTypes.func,
  confirmRemoveFile: PropTypes.func,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func,
  connectDragPreview: PropTypes.func
};

export default pipe(
  DragSource( "Photo", photoSource, Photo.collect )
)( Photo );
