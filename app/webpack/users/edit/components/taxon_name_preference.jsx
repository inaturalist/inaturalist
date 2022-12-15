import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { findDOMNode } from "react-dom";
import { DragSource, DropTarget } from "react-dnd";

/* global TAXON_NAME_LEXICONS */

const sourceSpec = {
  beginDrag: props => ( {
    taxonNamePreference: props.taxonNamePreference,
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

class TaxonNamePreference extends React.Component {
  render( ) {
    const {
      taxonNamePreference,
      deleteTaxonNamePreference,
      connectDragSource,
      connectDropTarget,
      isDragging
    } = this.props;
    let className = "TaxonNamePreference";
    if ( isDragging ) {
      className += " dragging";
    }
    let lexicon;
    if ( taxonNamePreference.lexicon ) {
      lexicon = TAXON_NAME_LEXICONS[taxonNamePreference.lexicon]
        ? TAXON_NAME_LEXICONS[taxonNamePreference.lexicon]
        : taxonNamePreference.lexicon;
    } else {
      lexicon = "Same as locale";
    }
    return connectDragSource( connectDropTarget(
      <div className={className}>
        <span className="index">{taxonNamePreference.position}</span>
        <span className="lexicon">{ lexicon }</span>
        { taxonNamePreference.place_id && (
          <span className="place">
            { taxonNamePreference.place_id }
          </span>
        ) }
        <button
          type="button"
          onClick={( ) => deleteTaxonNamePreference( taxonNamePreference.id )}
        >
          Delete
        </button>
      </div>
    ) );
  }
}

TaxonNamePreference.propTypes = {
  connectDropTarget: PropTypes.func.isRequired,
  connectDragSource: PropTypes.func.isRequired,
  taxonNamePreference: PropTypes.object,
  deleteTaxonNamePreference: PropTypes.func,
  isDragging: PropTypes.bool
};

export default _.flow(
  DragSource( "TaxonNamePreference", sourceSpec, sourceCollect ),
  DropTarget( "TaxonNamePreference", targetSpec, targetCollect )
)( TaxonNamePreference );
