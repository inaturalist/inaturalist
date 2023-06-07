import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import update from "immutability-helper";
import TaxonNamePriority from "./taxon_name_priority";

class TaxonNamePrioritiesDragdrop extends Component {
  constructor( ) {
    super( );
    this.reorderItem = this.reorderItem.bind( this );
    this.saveDroppedItem = this.saveDroppedItem.bind( this );
    this.state = {
      stateTaxonNamePriorities: []
    };
  }

  componentWillMount( ) {
    const { taxonNamePriorities } = this.props;
    if ( !_.isEmpty( taxonNamePriorities ) ) {
      this.setState( { stateTaxonNamePriorities: taxonNamePriorities } );
    }
  }

  componentWillReceiveProps( newProps ) {
    if ( newProps.taxonNamePriorities ) {
      this.setState( {
        stateTaxonNamePriorities: newProps.taxonNamePriorities
      } );
    }
  }

  // update the order of the temporary state of name priorities while a drag-to-reorder
  // is in progress. No API requests are made here - that happens when the drag is done
  reorderItem( dragIndex, hoverIndex ) {
    const { stateTaxonNamePriorities } = this.state;
    const dragItem = stateTaxonNamePriorities[dragIndex];
    if ( !dragItem ) {
      return;
    }
    if ( dragIndex === hoverIndex ) {
      return;
    }
    this.setState( update( this.state, {
      stateTaxonNamePriorities: {
        $splice: [
          [dragIndex, 1],
          [hoverIndex, 0, dragItem]
        ]
      }
    } ) );
  }

  // a name priority was moved. Make an update request to set its position to the position it was
  // moved to. The server will handle update the positions of other displaced name priorities
  saveDroppedItem( droppedItem ) {
    const { updateTaxonNamePriority } = this.props;
    const newPosition = _.orderBy( this.props.taxonNamePriorities, "position" )[droppedItem.index].position;
    if ( newPosition !== droppedItem.taxonNamePriority.position ) {
      updateTaxonNamePriority( droppedItem.taxonNamePriority.id, newPosition );
    }
  }

  render( ) {
    const {
      deleteTaxonNamePriority,
      updateTaxonNamePriority
    } = this.props;
    return (
      <div>
        { ( this.state.stateTaxonNamePriorities ).map( ( taxonNamePriority, index ) => (
          <TaxonNamePriority
            key={`taxon-name-priority-${taxonNamePriority.id}`}
            taxonNamePriority={taxonNamePriority}
            index={index}
            deleteTaxonNamePriority={deleteTaxonNamePriority}
            updateTaxonNamePriority={updateTaxonNamePriority}
            reorderItem={this.reorderItem}
            saveDroppedItem={this.saveDroppedItem}
          />
        ) ) }
      </div>
    );
  }
}

TaxonNamePrioritiesDragdrop.propTypes = {
  taxonNamePriorities: PropTypes.array,
  deleteTaxonNamePriority: PropTypes.func,
  updateTaxonNamePriority: PropTypes.func
};

export default TaxonNamePrioritiesDragdrop;
