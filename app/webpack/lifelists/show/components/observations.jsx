import React, { Component } from "react";
import PropTypes from "prop-types";
import Observation from "../../../projects/show/components/observation";

class Observations extends Component {
  constructor( props, context ) {
    super( props, context );
    let asdf = "ASdf";
  }

  render( ) {
    const {
      search, fetchNextPage, config
    } = this.props;
    let view;
    const loading = !search || ( !search.searchResponse && !search.loaded );
    const observations = loading ? null : search.searchResponse.results || [];
    if ( loading ) {
      view = ( <div className="loading_spinner huge" /> );
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
  fetchNextPage: PropTypes.func
};

export default Observations;
