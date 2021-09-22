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
    const {
      draggingProps,
      file,
      connectDragSource,
      onClick
    } = this.props;
    if (
      draggingProps
      && draggingProps.file
      && draggingProps.file.id === file.id
    ) {
      className += " drag";
    }
    return (
      <div>
        { connectDragSource(
          <div className={className}>
            <img
              alt={file.name}
              className="img-thumbnail"
              src={file.photo ? file.photo.large_url : file.preview}
              onClick={onClick}
            />
          </div>
        ) }
      </div>
    );
  }
}

Photo.propTypes = {
  file: PropTypes.object,
  onClick: PropTypes.func,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func
};

export default pipe(
  DragSource( "Photo", photoSource, Photo.collect )
)( Photo );
