import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { findDOMNode } from "react-dom";
import { DragSource, DropTarget } from "react-dnd";

/* global TAXON_NAME_LEXICONS */

const sourceSpec = {
  beginDrag: props => ( {
    taxonNamePriority: props.taxonNamePriority,
    index: props.index
  } ),
  endDrag( props, monitor ) {
    props.saveDroppedItem( monitor.getItem( ) );
  }
};

const targetSpec = {
  // see http://gaearon.github.io/react-dnd/examples-sortable-simple.html
  hover( props, monitor, component ) {
    const dragItem = monitor.getItem( );
    const dragIndex = dragItem.index;
    const hoverIndex = props.index;
    if ( dragIndex === hoverIndex ) {
      return;
    }
    const hoverBoundingRect = findDOMNode( component ).getBoundingClientRect( );
    const hoverMiddleY = ( hoverBoundingRect.bottom - hoverBoundingRect.top ) / 2;
    const clientOffset = monitor.getClientOffset( );
    const hoverClientY = clientOffset.y - hoverBoundingRect.top;
    if ( dragIndex < hoverIndex && hoverClientY < hoverMiddleY ) {
      return;
    }
    if ( dragIndex > hoverIndex && hoverClientY > hoverMiddleY ) {
      return;
    }
    props.reorderItem( dragIndex, hoverIndex );
    dragItem.index = hoverIndex;
  }
};

const sourceCollect = ( connect, monitor ) => ( {
  connectDragSource: connect.dragSource( ),
  isDragging: monitor.isDragging( )
} );

const targetCollect = connect => ( {
  connectDropTarget: connect.dropTarget( )
} );

class TaxonNamePriority extends React.Component {
  render( ) {
    const {
      taxonNamePriority,
      deleteTaxonNamePriority,
      connectDragSource,
      connectDropTarget,
      isDragging
    } = this.props;
    let className = "TaxonNamePriority";
    if ( isDragging ) {
      className += " dragging";
    }
    let lexicon;
    if ( taxonNamePriority.lexicon ) {
      lexicon = TAXON_NAME_LEXICONS[taxonNamePriority.lexicon]
        ? TAXON_NAME_LEXICONS[taxonNamePriority.lexicon]
        : taxonNamePriority.lexicon;
    } else {
      lexicon = I18n.t( "views.users.edit.taxon_name_priorities.same_as_locale" );
    }
    return connectDragSource( connectDropTarget(
      <div className={className}>
        <div className="move-icons">
          <div>
            <span className="glyphicon glyphicon-triangle-top" />
            <span className="glyphicon glyphicon-triangle-bottom" />
          </div>
        </div>
        <div className="lexicon">
          { lexicon }
          { taxonNamePriority.place && (
            <span className="place">
              { taxonNamePriority.place.display_name }
            </span>
          ) }
        </div>
        <div className="delete-button">
          <button
            type="button"
            className="btn btn-default"
            onClick={( ) => deleteTaxonNamePriority( taxonNamePriority.id )}
          >
            { I18n.t( "delete" ) }
          </button>
        </div>
      </div>
    ) );
  }
}

TaxonNamePriority.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  connectDragSource: PropTypes.func.isRequired,
  taxonNamePriority: PropTypes.object,
  deleteTaxonNamePriority: PropTypes.func,
  isDragging: PropTypes.bool
};

export default _.flow(
  DragSource( "TaxonNamePriority", sourceSpec, sourceCollect ),
  DropTarget( "TaxonNamePriority", targetSpec, targetCollect )
)( TaxonNamePriority );
