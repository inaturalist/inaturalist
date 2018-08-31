import React from "react";
import PropTypes from "prop-types";
import { DragSource as dragSource } from "react-dnd";
import { PHOTO_CHOOSER_DRAGGABLE_TYPE } from "./photo_chooser_constants";
import PhotoChoserPhoto from "./photo_chooser_photo";

const sourceSpec = {
  beginDrag: props => ( {
    id: props.id,
    chooserID: props.chooserID,
    origin: "external"
  } ),
  endDrag: ( props, monitor ) => {
    if ( monitor.didDrop( ) ) {
      if ( typeof( props.droppedPhoto ) === "function" ) {
        props.droppedPhoto( );
      }
    } else {
      props.didNotDropPhoto( );
    }
  }
};

const sourceCollect = ( connect, monitor ) => ( {
  connectDragSource: connect.dragSource( ),
  isDragging: monitor.isDragging( )
} );

class ExternalPhoto extends React.Component {
  render( ) {
    const {
      connectDragSource,
      src,
      isDragging,
      infoURL,
      chooserID
    } = this.props;
    return connectDragSource(
      <div
        className={
          `ExternalPhoto ${PHOTO_CHOOSER_DRAGGABLE_TYPE} ${isDragging ? "dragging" : null}`
        }
      >
        <PhotoChoserPhoto
          infoURL={infoURL}
          src={src}
          chooserID={chooserID}
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
  didNotDropPhoto: PropTypes.func,
  infoURL: PropTypes.string,
  chooserID: PropTypes.string,
};

export default dragSource(
  PHOTO_CHOOSER_DRAGGABLE_TYPE,
  sourceSpec,
  sourceCollect
)( ExternalPhoto );
