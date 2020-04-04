import React from "react";
import PropTypes from "prop-types";
import { DropTarget } from "react-dnd";
import { pipe } from "ramda";

const cardTargetSpec = {
  drop( props, monitor ) {
    const item = monitor.getItem( );
    props.insertCardsBefore( [item.obsCard.id], props.beforeCardId );
  }
};

const fileTargetSpec = {
  drop( props, monitor ) {
    const item = monitor.getItem( );
    props.insertFilesBefore( [item], props.beforeCardId );
  }
};

const cardTargetCollect = ( connect, monitor ) => ( {
  connectCardDropTarget: connect.dropTarget( ),
  cardIsOver: monitor.isOver( )
} );

const fileTargetCollect = ( connect, monitor ) => ( {
  connectFileDropTarget: connect.dropTarget( ),
  fileIsOver: monitor.isOver( )
} );

const InsertionDropTarget = ( {
  connectCardDropTarget,
  connectFileDropTarget,
  fileIsOver,
  cardIsOver,
  className
} ) => connectCardDropTarget( connectFileDropTarget(
  <div
    className={`InsertionDropTarget ${className} ${fileIsOver || cardIsOver ? "hover" : ""}`}
  />
) );

InsertionDropTarget.propTypes = {
  connectCardDropTarget: PropTypes.func.isRequired,
  connectFileDropTarget: PropTypes.func.isRequired,
  cardIsOver: PropTypes.bool,
  fileIsOver: PropTypes.bool,
  beforeCardId: PropTypes.number,
  insertCardsBefore: PropTypes.func,
  insertFilesBefore: PropTypes.func,
  className: PropTypes.string
};

export default pipe(
  DropTarget( "ObsCard", cardTargetSpec, cardTargetCollect ),
  DropTarget( ["Photo", "Sound"], fileTargetSpec, fileTargetCollect )
)( InsertionDropTarget );
