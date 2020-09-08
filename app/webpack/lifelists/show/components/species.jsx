import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

class Species extends Component {
  constructor( props, context ) {
    super( props, context );
    let asdf = "ASdf";
  }

  render( ) {
    const {
      search, fetchNextPage, config, lifelist, zoomToTaxon
    } = this.props;
    let view;
    const loaded = search && search.searchResponse;
    const species = loaded ? search.searchResponse.results || [] : null;
    if ( !loaded ) {
      view = ( <div className="loading_spinner huge" /> );
    } else if ( _.size( species ) === 0 ) {
      let emptyMessage;
      if ( _.size( species ) === 0 ) {
        if ( lifelist.speciesPlaceFilter ) {
          if ( lifelist.detailsTaxon ) {
            emptyMessage = `You have no unobserved species within this taxon in ${lifelist.speciesPlaceFilter.display_name}.`;
          } else {
            emptyMessage = `You have no unobserved species in ${lifelist.speciesPlaceFilter.display_name}.`;
          }
        } else if ( lifelist.detailsTaxon ) {
          emptyMessage = "You've observed all species within this taxon.";
        }
      }
      view = (
        <div className="empty">
          { emptyMessage }
        </div>
      );
    } else {
      view = _.map( species, s => {
        const onClick = e => {
          if ( zoomToTaxon ) {
            e.preventDefault( );
            zoomToTaxon( s.taxon.id, { detailsView: "observations" } );
          }
        };
        return (
          <div className="result" key={`grid_taxon_${s.taxon.id}`}>
            <TaxonThumbnail
              taxon={s.taxon}
              config={config}
              truncate={null}
              height={210}
              noInactive
              onClick={onClick}
              overlay={(
                <div>
                  <a
                    onClick={onClick}
                    href={`/observations?user_id=${lifelist.user.login}&taxon_id=${s.taxon.id}&place_id=any&verifiable=any`}
                  >
                    { I18n.t( "x_observations", { count: s.count } ) }
                  </a>
                </div>
              )}
            />
          </div>
        );
      } );
    }
    let moreButton;
    if ( search && search.hasMore ) {
      moreButton = !search.loaded
        ? ( <div className="loading_spinner big" /> )
        : (
          <button
            type="button"
            className="btn btn-sm btn-default"
            onClick={fetchNextPage}
          >
            <i className="fa fa-caret-down" />
            Show More
          </button>
        );
    }
    return (
      <div className="flex-container">
        <div className="SpeciesGrid unobserved">
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
  fetchNextPage: PropTypes.func,
  lifelist: PropTypes.object,
  zoomToTaxon: PropTypes.func
};

export default Species;
