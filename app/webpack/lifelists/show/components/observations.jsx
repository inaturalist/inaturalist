import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "../../../projects/show/components/observation";
import UserImage from "../../../shared/components/user_image";
import SplitTaxon from "../../../shared/components/split_taxon";

class Observations extends Component {
  constructor( props, context ) {
    super( props, context );
    let asdf = "ASdf";
  }

  render( ) {
    const {
      search, fetchFirstPage, fetchNextPage, config
    } = this.props;
    let view;
    const loading = !search || ( !search.searchResponse && !search.loaded );
    const observations = loading ? null : search.searchResponse.results || [];
    if ( loading ) {
      view = ( <div className="loading_spinner huge" /> );
      if ( search && !search.loading ) {
        fetchFirstPage( { firstPageSize: 4 } );
      }
    } else {
      view = observations.map( o => {
        const itemDim = 200;
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
        ? ( <div className="loading_spinner big" /> )
        : (
          <button
            className="btn btn-sm btn-default"
            onClick={fetchNextPage}
          >
            <i className="fa fa-caret-square-o-down" />
            Show More...
          </button>
        );
    }
    return (
      <div className="flex-container">
        <div className="ObservationsGrid" key="observations-flex-grid">
          { view }
          <div className="more">
            { moreButton }
          </div>
        </div>
      </div>
    );
  }
}

Observations.propTypes = {
  config: PropTypes.object,
  search: PropTypes.object,
  fetchFirstPage: PropTypes.func,
  fetchNextPage: PropTypes.func
};

export default Observations;
