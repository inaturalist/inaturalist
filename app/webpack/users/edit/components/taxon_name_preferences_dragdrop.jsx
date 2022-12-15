import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import update from "immutability-helper";
import TaxonNamePreference from "./taxon_name_preference";

class TaxonNamePreferencesDragdrop extends Component {
  constructor( ) {
    super( );
    this.reorderItem = this.reorderItem.bind( this );
    this.saveDroppedItem = this.saveDroppedItem.bind( this );
    this.state = {
      stateTaxonNamePreferences: []
    };
  }

  componentWillMount( ) {
    const { taxonNamePreferences } = this.props;
    if ( !_.isEmpty( taxonNamePreferences ) ) {
      this.setState( { stateTaxonNamePreferences: taxonNamePreferences } );
    }
  }

  componentWillReceiveProps( newProps ) {
    if ( newProps.taxonNamePreferences ) {
      this.setState( {
        stateTaxonNamePreferences: newProps.taxonNamePreferences
      } );
    }
  }

  // update the order of the temporary state of name preferences while a drag-to-reorder
  // is in progress. No API requests are made here - that happens when the drag is done
  reorderItem( dragIndex, hoverIndex ) {
    const { stateTaxonNamePreferences } = this.state;
    const dragItem = stateTaxonNamePreferences[dragIndex];
    if ( !dragItem ) {
      return;
    }
    if ( dragIndex === hoverIndex ) {
      return;
    }
    this.setState( update( this.state, {
      stateTaxonNamePreferences: {
        $splice: [
          [dragIndex, 1],
          [hoverIndex, 0, dragItem]
        ]
      }
    } ) );
  }

  // a name preference was moved. Make an update request to set its position to the position it was
  // moved to. The server will handle update the positions of other displaced preferences
  saveDroppedItem( droppedItem ) {
    const { updateTaxonNamePreference } = this.props;
    const newPosition = _.orderBy( this.props.taxonNamePreferences, "position" )[droppedItem.index].position;
    if ( newPosition !== droppedItem.taxonNamePreference.position ) {
      updateTaxonNamePreference( droppedItem.taxonNamePreference.id, newPosition );
    }
  }

  render( ) {
    const {
      deleteTaxonNamePreference,
      updateTaxonNamePreference
    } = this.props;
    return (
      <div>
        { ( this.state.stateTaxonNamePreferences ).map( ( taxonNamePreference, index ) => (
          <TaxonNamePreference
            key={`taxon-name-preference-${taxonNamePreference.id}`}
            taxonNamePreference={taxonNamePreference}
            index={index}
            deleteTaxonNamePreference={deleteTaxonNamePreference}
            updateTaxonNamePreference={updateTaxonNamePreference}
            reorderItem={this.reorderItem}
            saveDroppedItem={this.saveDroppedItem}
          />
        ) ) }
      </div>
    );
  }
}

TaxonNamePreferencesDragdrop.propTypes = {
  taxonNamePreferences: PropTypes.array,
  deleteTaxonNamePreference: PropTypes.func,
  updateTaxonNamePreference: PropTypes.func
};

export default TaxonNamePreferencesDragdrop;
