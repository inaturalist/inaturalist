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
    className += " btn btn-nostyle";
    let imgSrc = file.photo ? file.photo.large_url : file.preview;
    // If there's no remote file yet and this is an HEIC/HEIF, then
    // the "preview" will not natively render in any browser other than
    // Safari, so we show a loading spinner instead
    if ( !file?.photo?.large_url && ( file.type === "image/heic" || file.type === "image/heif" ) ) {
      imgSrc = null;
    }
    return (
      <div>
        { connectDragSource(
          <button className={className} onClick={onClick} type="button">
            {
              imgSrc
                ? (
                  <img
                    alt={file.name}
                    className="img-thumbnail"
                    src={imgSrc}
                  />
                )
                : <div className="loading_spinner" />
            }
          </button>
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
