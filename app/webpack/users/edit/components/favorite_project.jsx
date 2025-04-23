import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { DragSource, DropTarget } from "react-dnd";

import DraggableOption from "./draggable_option";

const sourceSpec = {
  beginDrag: props => ( {
    // ensure the monitor has this value so we can use it below in the hover
    // callback
    position: props.position
  } ),
  endDrag( sourceProps ) {
    sourceProps.onChange( );
  }
};

const targetSpec = {
  // Callback that runs when the source is dragged over a target
  hover( targetProps, monitor, targetComponent ) {
    const sourceItem = monitor.getItem( ); // the thing being dragged
    if ( !targetComponent ) return;
    if ( sourceItem.position === targetProps.position ) {
      return;
    }

    // All of the FavoriteProjects receive this callback, so it doesn't matter
    // which one you call it on
    targetProps.onDrag( sourceItem.position, targetProps.position );

    // without this you will get drag events and repositioning
    sourceItem.position = targetProps.position;
  }
};

const sourceCollect = ( connect, monitor ) => ( {
  connectDragSource: connect.dragSource( ),
  isDragging: monitor.isDragging( )
} );

const targetCollect = connect => ( {
  connectDropTarget: connect.dropTarget( )
} );

// Needs to be a class component to access the component in the targetSpec
class FavoriteProject extends React.Component {
  render() {
    const {
      connectDragSource,
      connectDropTarget,
      isDragging,
      onRemove,
      project
    } = this.props;
    return connectDragSource( connectDropTarget( (
      <div>
        <DraggableOption isDragging={isDragging} onRemove={() => onRemove( project )}>
          { project.title }
        </DraggableOption>
      </div>
    ) ) );
  }
}

FavoriteProject.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  connectDragSource: PropTypes.func.isRequired,
  isDragging: PropTypes.bool,
  // These callbacks are used, just not in the component definition
  // eslint-disable-next-line react/no-unused-prop-types
  onChange: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  onDrag: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  position: PropTypes.number,
  onRemove: PropTypes.func,
  project: PropTypes.object
};

export default _.flow(
  DragSource( "FavoriteProject", sourceSpec, sourceCollect ),
  DropTarget( "FavoriteProject", targetSpec, targetCollect )
)( FavoriteProject );
