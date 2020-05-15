import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import Observation from "../../../projects/show/components/observation";
import UserImage from "../../../shared/components/user_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

class Species extends Component {
  constructor( props, context ) {
    super( props, context );
    let asdf = "ASdf";
  }

  render( ) {
    const {
      search, fetchFirstPage, fetchNextPage, config, lifelist
    } = this.props;
    let view;
    const loading = !search || ( !search.searchResponse && !search.loaded );
    const species = loading ? null : search.searchResponse.results || [];
    if ( loading ) {
      view = ( <div className="loading_spinner huge" /> );
      if ( search && !search.loading ) {
        fetchFirstPage( { firstPageSize: 4 } );
      }
    } else {
      view = _.map( species, s => (
        <div className="result" key={`grid_taxon_${s.taxon.id}`}>
          <TaxonThumbnail
            taxon={s.taxon}
            config={config}
            truncate={null}
            height={210}
            noInactive
            overlay={(
              <div>
                <a href={`/observations?user_id=${lifelist.user.login}&taxon_id=${s.taxon.id}&place_id=any&verifiable=any`}>
                  { I18n.t( "x_observations", { count: s.count } ) }
                </a>
              </div>
            )}
          />
        </div>
      ) );
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
        <div className="SpeciesGrid">
          { view }
          <div className="more">
            { moreButton }
          </div>
        </div>
      </div>
    );
  }
}

Species.propTypes = {
  config: PropTypes.object,
  search: PropTypes.object,
  fetchFirstPage: PropTypes.func,
  fetchNextPage: PropTypes.func,
  lifelist: PropTypes.object
};

export default Species;
