import React, { PropTypes } from "react";
import { findDOMNode } from "react-dom";
import { DragSource as dragSource, DropTarget as dropTarget } from "react-dnd";
import _ from "lodash";

const TYPE = "DraggablePhoto";

const sourceSpec = {
  beginDrag: props => {
    return {
      id: props.id,
      index: props.index,
      origin: "chosen"
    };
  }
};

const targetSpec = {
  // http://gaearon.github.io/react-dnd/examples-sortable-simple.html
  hover( props, monitor, component ) {
    console.log( "[DEBUG] ChosenPhoto hover" );
    const dragPhoto = monitor.getItem( );
    const dragIndex = dragPhoto.index;
    const hoverIndex = props.index;
    if ( dragIndex === hoverIndex && dragPhoto.origin === "chosen" ) {
      return;
    }
    if ( dragPhoto.origin === "external" ) {
      props.newPhotoEnter( dragPhoto.id, hoverIndex );
    }
    const hoverBoundingRect = findDOMNode( component ).getBoundingClientRect( );
    const hoverMiddleX = ( hoverBoundingRect.right - hoverBoundingRect.left ) / 2;
    const hoverMiddleY = ( hoverBoundingRect.bottom - hoverBoundingRect.top ) / 2;
    const clientOffset = monitor.getClientOffset( );
    const hoverClientX = clientOffset.x - hoverBoundingRect.left;
    const hoverClientY = clientOffset.y - hoverBoundingRect.top;
    // Dragging downwards
    if ( dragIndex < hoverIndex && hoverClientY < hoverMiddleY && hoverClientX < hoverMiddleX ) {
      console.log( "[DEBUG] dragging down, skip" );
      return;
    }
    // Dragging upwards
    if ( dragIndex > hoverIndex && hoverClientY > hoverMiddleY && hoverClientX > hoverMiddleX ) {
      console.log( "[DEBUG] dragging up, skip" );
      return;
    }
    console.log( "[DEBUG] moving position" );
    props.movePhoto( dragIndex, hoverIndex );
    dragPhoto.index = hoverIndex;
  },
  drop( props, monitor, component ) {
    const dragPhoto = monitor.getItem( );
    if ( dragPhoto.origin === "external" ) {
      console.log( "[DEBUG] firing dropNewPhoto" )
      props.dropNewPhoto( dragPhoto.id );
    }
  }
};

const sourceCollect = ( connect, monitor ) => {
  return {
    connectDragSource: connect.dragSource( ),
    isDragging: monitor.isDragging( )
  };
};

const targetCollect = ( connect, monitor ) => {
  return {
    connectDropTarget: connect.dropTarget( )
  };
};

class ChosenPhoto extends React.Component {
  render( ) {
    const {
      connectDragSource,
      connectDropTarget,
      src,
      isDragging,
      candidate,
      id,
      removePhoto
    } = this.props;
    const appearAsDropTarget = isDragging || candidate;
    console.log( "[DEBUG] ", id, ": isDragging: ", isDragging, ", candidate: ", candidate );
    return connectDragSource( connectDropTarget(
      <div className={`ChosenPhoto ${appearAsDropTarget ? "hovering" : ""}`}>
        <a onClick={ ( ) => removePhoto( id ) }>
          <i className="fa fa-times-circle"></i>
        </a>
        <img src={src} />
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
  id: PropTypes.string,
  movePhoto: PropTypes.func,
  removePhoto: PropTypes.func
};

// export default ChosenPhoto;
export default _.flow(
  dragSource( TYPE, sourceSpec, sourceCollect ),
  dropTarget( TYPE, targetSpec, targetCollect )
)( ChosenPhoto );
