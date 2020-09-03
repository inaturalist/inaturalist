import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import Observation from "../../../projects/show/components/observation";

// eslint-disable-next-line react/prefer-stateless-function
class Observations extends Component {
  render( ) {
    const {
      lifelist, search, fetchNextPage, config, setSpeciesPlaceFilter
    } = this.props;
    let view;
    const loading = !search || ( !search.searchResponse && !search.loaded );
    const observations = loading ? null : search.searchResponse.results || [];
    let emptyMessage;
    let emptyClearButton;
    if ( loading ) {
      view = ( <div className="loading_spinner huge" /> );
    } else if ( _.isEmpty( observations ) && lifelist.speciesPlaceFilter ) {
      if ( lifelist.detailsTaxon ) {
        emptyMessage = `No observations found within this taxon in ${lifelist.speciesPlaceFilter.display_name}.`;
      } else {
        emptyMessage = `No observations found in ${lifelist.speciesPlaceFilter.display_name}.`;
      }
      emptyClearButton = (
        <button
          type="button"
          className="btn btn-primary"
          onClick={( ) => setSpeciesPlaceFilter( null )}
        >
          Reset Place Filter
        </button>
      );
    } else {
      view = observations.map( o => {
        const itemDim = 210;
        let width = itemDim;
        const dims = o.photos.length > 0 && o.photos[0].dimensions( );
        if ( dims ) {
          width = itemDim / dims.height * dims.width;
        } else {
          width = itemDim;
        }
        return (
          <Observation
            key={`obs-${o.id}`}
            observation={o}
            width={width}
            height={itemDim}
            config={config}
          />
        );
      } );
    }
    let moreButton;
    if ( search && search.hasMore ) {
      moreButton = !search.loaded
        ? ( <div className="more"><div className="loading_spinner big" /></div> )
        : (
          <div className="more">
            <button
              type="button"
              className="btn btn-sm btn-default"
              onClick={fetchNextPage}
            >
              <i className="fa fa-caret-down" />
              Show More
            </button>
          </div>
        );
    }
    return (
      <div className="flex-container">
        <div className="ObservationsGrid" key="observations-flex-grid">
          { emptyMessage && (
            <div className="empty">
              { emptyMessage }
              { emptyClearButton }
            </div>
          ) }
          { view }
          { moreButton }
        </div>
      </div>
    );
  }
}

Observations.propTypes = {
  config: PropTypes.object,
  search: PropTypes.object,
  fetchNextPage: PropTypes.func,
  lifelist: PropTypes.object,
  setSpeciesPlaceFilter: PropTypes.func
};

export default Observations;
