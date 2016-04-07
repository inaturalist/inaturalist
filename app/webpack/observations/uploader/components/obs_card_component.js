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
        `You dropped ${item.obsCard.name} into ${dropResult.obsCard.name}!`
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

const ObsCardComponent = ( { obsCard, nameChange, descriptionChange, connectDropTarget,
                 connectDragSource, isOver, isDragging, removeObsCard } ) => {
  let className = "card ui-selectee";
  if ( isDragging ) {
    className += " dragging";
  }
  if ( isOver ) {
    className += " dragOver";
  }
  if ( obsCard.selected ) {
    className += " selected ui-selecting";
  }
  let img;
  if ( obsCard.upload_state === "pending" ) {
    img = ( <span className="glyphicon glyphicon-hourglass" aria-hidden="true"></span> );
  } else if ( obsCard.upload_state === "uploading" ) {
    img = ( <span className="glyphicon glyphicon-refresh fa-spin" aria-hidden="true"></span> );
  } else if ( obsCard.upload_state === "uploaded" && obsCard.photo ) {
    img = ( <img src={ obsCard.photo.small_url } /> );
  } else {
    img = ( <div className="placeholder" /> );
  }
  return (
    <div className="cell" key={ obsCard.id }>
      {
        connectDropTarget( connectDragSource(
          <div className={ className } data-id={ obsCard.id }>
            <div className="move">
              <span className="glyphicon glyphicon-record" aria-hidden="true"></span>
            </div>
            <div className="close" onClick={ removeObsCard }>
              <span className="glyphicon glyphicon-remove-sign" aria-hidden="true"></span>
            </div>
            <div className="image">
              { img }
            </div>
            <input type="text" placeholder="Add a title"
              value={ obsCard.name } onChange={ nameChange }
            />
            <input type="textarea" placeholder="Add a description"
              value={ obsCard.description } onChange={ descriptionChange }
            />
          </div>
        ) )
      }
  </div>
  );
};

ObsCardComponent.propTypes = {
  obsCard: PropTypes.object,
  nameChange: PropTypes.func,
  removeObsCard: PropTypes.func,
  descriptionChange: PropTypes.func,
  connectDropTarget: PropTypes.func,
  connectDragSource: PropTypes.func,
  isOver: PropTypes.bool,
  isDragging: PropTypes.bool
};

export default pipe(
  DragSource( "ObsCard", cardSource, collect ),
  DropTarget( "ObsCard", cardTarget, collectDrop )
)( ObsCardComponent );
