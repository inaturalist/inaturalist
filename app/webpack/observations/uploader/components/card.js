import React, { PropTypes } from "react";
import { DragSource, DropTarget } from "react-dnd";
import { pipe } from "ramda";

const cardSource = {
  beginDrag( props ) {
    return props;
  }
};

const cardTarget = {
  drop( props, monitor, component ) {
    const item = monitor.getItem( );
    const dropResult = component.props;

    if ( dropResult ) {
      console.log(
        `You dropped ${item.file.name} into ${dropResult.file.name}!`
      );
    }
  }
};

function collect( connect, monitor ) {
  return {
    connectDragSource: connect.dragSource( ),
    isDragging: monitor.isDragging( )
  };
}

function collectDrop( connect, monitor ) {
  return {
    connectDropTarget: connect.dropTarget( ),
    isOver: monitor.isOver( ),
    canDrop: monitor.canDrop( )
  };
}

const Card = ( { file, index, nameChange, descriptionChange, connectDropTarget,
                 connectDragSource, isOver, isDragging } ) => {
  let s = { opacity: isDragging ? 0 : 1 };
  if ( isOver ) {
    s.border = "1px solid green";
  }
  return (
    <div className="cell">
    {
      connectDropTarget( connectDragSource(
        <div className="card" style={ s } index={ index }>
          <div className="title">
            <img key={ file.name } src={ file.preview } />
            <h4>{file.name}</h4>
            <input type="text" placeholder="Add a title"
              value={ file.name } onChange={ nameChange } />
            <input type="textarea" placeholder="Add a description"
              value={ file.description } onChange={ descriptionChange } />
          </div>
        </div>
      ) )
    }
  </div>
  );
};

Card.propTypes = {
  file: PropTypes.object,
  index: PropTypes.number,
  nameChange: PropTypes.func,
  descriptionChange: PropTypes.func,
  connectDropTarget: PropTypes.func,
  connectDragSource: PropTypes.func,
  isOver: PropTypes.bool,
  isDragging: PropTypes.bool
};

export default pipe(
  DragSource( "Card", cardSource, collect ),
  DropTarget( "Card", cardTarget, collectDrop )
)( Card );
