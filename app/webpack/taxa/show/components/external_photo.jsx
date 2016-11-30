import React, { PropTypes } from "react";
import { DragSource as dragSource } from "react-dnd";

const TYPE = "DraggablePhoto";

const sourceSpec = {
  beginDrag: props => {
    return {
      id: props.id,
      origin: "external"
    };
  },
  endDrag: ( props, monitor, component ) => {
    if ( monitor.didDrop( ) ) {
      console.log( "[DEBUG] dropped ExternalPhoto" );
      if ( typeof( props.droppedPhoto ) === "function" ) {
        console.log( "[DEBUG] firing droppedPhoto" );
        props.droppedPhoto( );
      }
    } else {
      console.log( "[DEBUG] DID NOT drop ExternalPhoto" );
      props.didNotDropPhoto( );
    }
  }
};

const sourceCollect = ( connect, monitor ) => {
  return {
    connectDragSource: connect.dragSource( ),
    isDragging: monitor.isDragging( )
  };
};

class ExternalPhoto extends React.Component {
  render( ) {
    const {
      connectDragSource,
      src,
      isDragging
    } = this.props;
    return connectDragSource(
      <div
        style={{
          display: "inline-block"
        }}
      >
        <img
          src={src}
          style={{
            opacity: isDragging ? 0.5 : 1
          }}
        />
      </div>
    );
  }
}

ExternalPhoto.propTypes = {
  connectDragSource: PropTypes.func.isRequired,
  src: PropTypes.string.isRequired,
  isDragging: PropTypes.bool,
  moveCard: PropTypes.func,
  droppedPhoto: PropTypes.func,
  didNotDropPhoto: PropTypes.func
};

export default dragSource( TYPE, sourceSpec, sourceCollect )( ExternalPhoto );
