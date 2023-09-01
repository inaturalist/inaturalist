import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

// eslint-disable-next-line react/prefer-stateless-function
class Species extends Component {
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
            emptyMessage = I18n.t( "views.lifelists.no_unobserved_species_within_this_taxon_in_place", {
              place: lifelist.speciesPlaceFilter.display_name
            } );
          } else {
            emptyMessage = I18n.t( "views.lifelists.no_unobserved_species_in_place", {
              place: lifelist.speciesPlaceFilter.display_name
            } );
          }
        } else if ( lifelist.detailsTaxon ) {
          emptyMessage = I18n.t( "views.lifelists.no_unobserved_species_within_this_taxon" );
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
        let taxonLink = `/observations?unobserved_by_user_id=${lifelist.user.login}&taxon_id=${s.taxon.id}&quality_grade=research`;
        taxonLink += lifelist.speciesPlaceFilter
          ? `&place_id=${lifelist.speciesPlaceFilter.id}`
          : "&place_id=any";
        return (
          <div className="result d-flex" key={`grid_taxon_${s.taxon.id}`}>
            <TaxonThumbnail
              className="flex-grow-1"
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
                    href={taxonLink}
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
            { I18n.t( "show_more" ) }
          </button>
        );
    }
    return (
      <div className="Details">
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
