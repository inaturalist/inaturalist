import React from "react";
import PropTypes from "prop-types";
import { DropTarget } from "react-dnd";
import Dropzone from "react-dropzone";
import _ from "lodash";
import { ACCEPTED_FILE_TYPES } from "../models/util";

const cardTargetSpec = {
  drop( props, monitor ) {
    const item = monitor.getItem( );
    props.insertCardsBefore( [item.obsCard.id], props.beforeCardId );
  }
};

const fileTargetSpec = {
  drop( props, monitor ) {
    const item = monitor.getItem( );
    props.insertExistingFilesBefore( [item], props.beforeCardId );
  }
};

const cardTargetCollect = connect => ( {
  connectCardDropTarget: connect.dropTarget( )
} );

const fileTargetCollect = connect => ( {
  connectFileDropTarget: connect.dropTarget( )
} );

// Note that without the Dropzone element, Firefox doesn't recognize the
// dragenter events and props from the collect methods don't get passed in.
// Instead we need to rely on the activeClass and onDragEnter props on
// Dropzone. We also need Dropzone to handle file drops from the
const InsertionDropTarget = ( {
  connectCardDropTarget,
  connectFileDropTarget,
  className,
  insertDroppedFilesBefore,
  beforeCardId
} ) => connectCardDropTarget( connectFileDropTarget(
  <div className="InsertionDropTarget">
    <Dropzone
      className={`dropzone ${className}`}
      activeClassName="hover"
      disableClick
      accept={ACCEPTED_FILE_TYPES}
      onDrop={acceptedFiles => {
        if ( acceptedFiles.length === 0 ) {
          // This will happen if the files are not actual filesystem files that
          // were dragged onto the window, e.g. for file components or obs card
          // components. Those drops get handled by the target specs defined
          // above
          return;
        }
        insertDroppedFilesBefore( acceptedFiles, beforeCardId );
      }}
    />
  </div>
) );

InsertionDropTarget.propTypes = {
  connectCardDropTarget: PropTypes.func.isRequired,
  connectFileDropTarget: PropTypes.func.isRequired,
  cardIsOver: PropTypes.bool,
  fileIsOver: PropTypes.bool,
  beforeCardId: PropTypes.number,
  insertCardsBefore: PropTypes.func,
  insertExistingFilesBefore: PropTypes.func,
  insertDroppedFilesBefore: PropTypes.func,
  className: PropTypes.string
};

export default _.flow(
  DropTarget( ["ObsCard"], cardTargetSpec, cardTargetCollect ),
  DropTarget( ["Photo", "Sound"], fileTargetSpec, fileTargetCollect )
)( InsertionDropTarget );
