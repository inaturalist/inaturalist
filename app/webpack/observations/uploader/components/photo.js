import React, { PropTypes, Component } from "react";
import { DragSource } from "react-dnd";
import { pipe } from "ramda";

const photoSource = {
  beginDrag( props ) {
    props.setState( { draggingProps: props } );
    props.updateObsCard( props.obsCard, { cardIsDragging: true } );
    return props;
  },
  endDrag( props ) {
    props.setState( { draggingProps: null } );
    props.updateObsCard( props.obsCard, { cardIsDragging: false } );
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
            <img className="img-thumbnail" src={ this.props.file.photo.large_url } />
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
  setState: PropTypes.func,
  updateCard: PropTypes.func,
  confirmRemoveFile: PropTypes.func,
  draggingProps: PropTypes.object,
  connectDragSource: PropTypes.func,
  connectDragPreview: PropTypes.func
};

export default pipe(
  DragSource( "Photo", photoSource, Photo.collect )
)( Photo );
