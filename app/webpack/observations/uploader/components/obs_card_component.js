import React, { PropTypes } from "react";
import { DragSource, DropTarget } from "react-dnd";
import { pipe } from "ramda";
import TaxonAutocomplete from "../../identify/components/taxon_autocomplete";
import Dropzone from "react-dropzone";

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
        `You dropped ${item.obsCard.description} into ${dropResult.obsCard.description}!`
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

const ObsCardComponent = ( { obsCard, connectDropTarget, onCardDrop,
                 connectDragSource, isOver, isDragging, removeObsCard, updateObsCard } ) => {
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
    <Dropzone className="cellDropzone" disableClick disablePreview onDrop={
      ( f, e ) => onCardDrop( f, e, obsCard ) } activeClassName="hover"
    >
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
            <TaxonAutocomplete key={ obsCard.selected_taxon ? obsCard.selected_taxon.id : undefined }
              bootstrapClear
              searchExternal={false}
              initialSelection={ obsCard.selected_taxon }
              afterSelect={ function ( result ) {
                updateObsCard( obsCard, { taxon_id: result.item.id, selected_taxon: result.item } );
              } }
              afterUnselect={ function ( ) {
                if ( obsCard.taxon_id ) {
                  updateObsCard( obsCard, { taxon_id: undefined, selected_taxon: undefined } );
                }
              } }
            />
            <input type="textarea" placeholder="Add a description"
              value={ obsCard.description } onChange={ e =>
                updateObsCard( obsCard, { description: e.target.value } ) }
            />
          </div>
        ) )
      }
    </div>
      </Dropzone>
  );
};

ObsCardComponent.propTypes = {
  obsCard: PropTypes.object,
  removeObsCard: PropTypes.func,
  connectDropTarget: PropTypes.func,
  connectDragSource: PropTypes.func,
  isOver: PropTypes.bool,
  isDragging: PropTypes.bool,
  updateObsCard: PropTypes.func,
  onCardDrop: PropTypes.func
};

export default pipe(
  DragSource( "ObsCard", cardSource, collect ),
  DropTarget( "ObsCard", cardTarget, collectDrop )
)( ObsCardComponent );
