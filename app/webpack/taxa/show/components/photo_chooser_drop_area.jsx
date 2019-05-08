import React from "react";
import PropTypes from "prop-types";
import { DropTarget as dropTarget } from "react-dnd";
import _ from "lodash";
import { PHOTO_CHOOSER_DRAGGABLE_TYPE } from "./photo_chooser_constants";
import { MAX_TAXON_PHOTOS } from "../../shared/util";

const targetSpec = {
  drop( props, monitor ) {
    const { photos } = props;
    if ( photos.length > MAX_TAXON_PHOTOS - 1 ) {
      return;
    }
    props.droppedPhoto( monitor.getItem( ).chooserID );
  }
};

const targetCollect = ( connect, monitor ) => ( {
  connectDropTarget: connect.dropTarget( ),
  isHovering: monitor.isOver( )
} );

class PhotoChooserDropArea extends React.Component {
  render( ) {
    const { connectDropTarget, isHovering, children } = this.props;
    return connectDropTarget(
      <div
        className={`PhotoChooserDropArea ${isHovering ? "hovering" : ""}`}
      >
        { children }
      </div>
    );
  }
}

PhotoChooserDropArea.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  photos: PropTypes.array,
  isHovering: PropTypes.bool,
  droppedPhoto: PropTypes.func,
  children: PropTypes.array
};

export default _.flow(
  dropTarget( PHOTO_CHOOSER_DRAGGABLE_TYPE, targetSpec, targetCollect )
)( PhotoChooserDropArea );
