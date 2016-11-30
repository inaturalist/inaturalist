import React, { PropTypes } from "react";
// import { findDOMNode } from "react-dom";
import { DropTarget as dropTarget } from "react-dnd";
import _ from "lodash";

const TYPE = "DraggablePhoto";

const targetSpec = {
  drop( props, monitor ) {
    console.log( "[DEBUG] dropped into drop area, monitor.getItem( ): ", monitor.getItem( ) );
    props.droppedPhoto( monitor.getItem( ).id );
  }
};

const targetCollect = ( connect, monitor ) => ( {
  connectDropTarget: connect.dropTarget( ),
  isHovering: monitor.isOver( )
} );

class PhotoChooserDropArea extends React.Component {
  render( ) {
    const { connectDropTarget, isHovering } = this.props;
    return connectDropTarget(
      <div
        style={{
          border: isHovering ? "1px dashed blue" : "1px solid blue"
        }}
      >
        PhotoChooserDropArea
      </div>
    );
  }
}

PhotoChooserDropArea.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  photos: PropTypes.array,
  isHovering: PropTypes.bool,
  droppedPhoto: PropTypes.func
};

export default _.flow(
  dropTarget( TYPE, targetSpec, targetCollect )
)( PhotoChooserDropArea );
