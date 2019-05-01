import React from "react";
import PropTypes from "prop-types";
import { findDOMNode } from "react-dom";
import { DragSource as dragSource, DropTarget as dropTarget } from "react-dnd";
import _ from "lodash";
import { MAX_TAXON_PHOTOS } from "../../shared/util";
import { PHOTO_CHOOSER_DRAGGABLE_TYPE } from "./photo_chooser_constants";
import PhotoChooserPhoto from "./photo_chooser_photo";

const sourceSpec = {
  beginDrag: props => ( {
    id: props.id,
    chooserID: props.chooserID,
    index: props.index,
    origin: "chosen"
  } )
};

const targetSpec = {
  // http://gaearon.github.io/react-dnd/examples-sortable-simple.html
  hover( props, monitor, component ) {
    const dragPhoto = monitor.getItem( );
    const dragIndex = dragPhoto.index;
    const hoverIndex = props.index;
    if ( dragIndex === hoverIndex && dragPhoto.origin === "chosen" ) {
      return;
    }
    if ( dragPhoto.origin === "external" ) {
      props.newPhotoEnter( dragPhoto.chooserID, hoverIndex );
    }
    const hoverBoundingRect = findDOMNode( component ).getBoundingClientRect( );
    const hoverMiddleX = ( hoverBoundingRect.right - hoverBoundingRect.left ) / 2;
    const hoverMiddleY = ( hoverBoundingRect.bottom - hoverBoundingRect.top ) / 2;
    const clientOffset = monitor.getClientOffset( );
    const hoverClientX = clientOffset.x - hoverBoundingRect.left;
    const hoverClientY = clientOffset.y - hoverBoundingRect.top;
    // Dragging downwards
    if ( dragIndex < hoverIndex && hoverClientY < hoverMiddleY && hoverClientX < hoverMiddleX ) {
      return;
    }
    // Dragging upwards
    if ( dragIndex > hoverIndex && hoverClientY > hoverMiddleY && hoverClientX > hoverMiddleX ) {
      return;
    }
    props.movePhoto( dragIndex, hoverIndex );
    dragPhoto.index = hoverIndex;
  },
  drop( props, monitor ) {
    const dragPhoto = monitor.getItem( );
    const { totalChosenPhotos } = props;
    if ( dragPhoto.origin === "external" ) {
      if ( totalChosenPhotos >= MAX_TAXON_PHOTOS ) {
        props.removePhoto( dragPhoto.chooserID );
        return;
      }
      props.dropNewPhoto( dragPhoto.chooserID );
    }
  }
};

const sourceCollect = ( connect, monitor ) => ( {
  connectDragSource: connect.dragSource( ),
  isDragging: monitor.isDragging( )
} );

const targetCollect = connect => ( {
  connectDropTarget: connect.dropTarget( )
} );

class ChosenPhoto extends React.Component {
  render( ) {
    const {
      connectDragSource,
      connectDropTarget,
      src,
      isDragging,
      candidate,
      chooserID,
      removePhoto,
      infoURL,
      isDefault
    } = this.props;
    const appearAsDropTarget = isDragging || candidate;
    let className = `ChosenPhoto ${PHOTO_CHOOSER_DRAGGABLE_TYPE}`;
    if ( appearAsDropTarget ) {
      className += " hovering";
    }
    return connectDragSource( connectDropTarget(
      <div className={className}>
        <PhotoChooserPhoto
          removePhoto={removePhoto}
          infoURL={infoURL}
          src={src}
          chooserID={chooserID}
        />
        { isDefault ? (
          <span className="default-control">{ I18n.t( "default" ) }</span>
        ) : null }
      </div>
    ) );
  }
}

ChosenPhoto.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  connectDragSource: PropTypes.func.isRequired,
  src: PropTypes.string.isRequired,
  isDragging: PropTypes.bool,
  candidate: PropTypes.bool,
  index: PropTypes.number.isRequired,
  chooserID: PropTypes.string,
  movePhoto: PropTypes.func,
  removePhoto: PropTypes.func,
  infoURL: PropTypes.string,
  isDefault: PropTypes.bool,
  totalChosenPhotos: PropTypes.number
};

// export default ChosenPhoto;
export default _.flow(
  dragSource( PHOTO_CHOOSER_DRAGGABLE_TYPE, sourceSpec, sourceCollect ),
  dropTarget( PHOTO_CHOOSER_DRAGGABLE_TYPE, targetSpec, targetCollect )
)( ChosenPhoto );
