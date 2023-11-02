import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Badge } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import APIWrapper from "../../../shared/containers/inat_api_duck_container";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import Observations from "./observations";
import Species from "./species";
import SpeciesNoAPIContainer from "../containers/species_noapi_container";
import { filteredNodes, rankLabel } from "../util";

const ObservationsGridContainer = APIWrapper( "observations", Observations );
const UnobservedSpeciesGridContainer = APIWrapper( "unobservedSpecies", Species );

const DetailsView = ( {
  lifelist, setSpeciesPlaceFilter, setObservationSort,
  setDetailsTaxon, inatAPI
} ) => {
  let view;
  let searchOptions;
  if ( lifelist.detailsView === "species" ) {
    view = ( <SpeciesNoAPIContainer /> );
  } else if ( lifelist.detailsView === "unobservedSpecies" ) {
    view = (
      <UnobservedSpeciesGridContainer
        lifelist={lifelist}
        setDetailisTaxon={setDetailsTaxon}
        setSpeciesPlaceFilter={setSpeciesPlaceFilter}
      />
    );
  } else {
    view = (
      <ObservationsGridContainer
        lifelist={lifelist}
        setSpeciesPlaceFilter={setSpeciesPlaceFilter}
        setObservationSort={setObservationSort}
      />
    );
  }
  let stats;
  let title;
  let inatAPIsearch;
  let searchLoaded;
  if ( lifelist.detailsView === "observations" ) {
    inatAPIsearch = inatAPI.observations;
    searchLoaded = inatAPIsearch && inatAPIsearch.searchResponse;
    if ( lifelist.detailsTaxon ) {
      const isLeaf = !lifelist.children[lifelist.detailsTaxon.id];
      if ( lifelist.speciesPlaceFilter ) {
        const label = isLeaf
          ? I18n.t( "views.lifelists.observations_at_this_taxon" )
          : I18n.t( "views.lifelists.observations_within_this_taxon" );
        stats = (
          <div className="stats">
            <span className="stat">
              <span className="attr">
                {label}
              </span>
              <span className="value">
                { searchLoaded
                  ? I18n.toNumber( inatAPIsearch.searchResponse.total_results, { precision: 0 } )
                  : ( <div className="loading_spinner" /> ) }
              </span>
            </span>
          </div>
        );
      } else {
        const hasDirectObs = lifelist.detailsTaxon.direct_obs_count > 0;
        const hasDescendantObs = lifelist.detailsTaxon.descendant_obs_count > 0;
        const descendantsStats = (
          <button
            type="button"
            className={`stat ${lifelist.detailsTaxonExact ? "" : "selected "}${hasDescendantObs ? "clicky" : ""}`}
            onClick={( ) => hasDescendantObs && setDetailsTaxon( lifelist.detailsTaxon )}
          >
            <span className="attr">
              { I18n.t( "views.lifelists.observations_within_this_taxon" ) }
            </span>
            <span className="value">
              { I18n.toNumber( lifelist.detailsTaxon.descendant_obs_count, { precision: 0 } ) }
            </span>
          </button>
        );
        stats = (
          <div className="stats">
            <button
              type="button"
              className={`stat ${isLeaf || lifelist.detailsTaxonExact ? "selected " : ""}${
                hasDirectObs ? "clicky" : ""}`}
              onClick={( ) => hasDirectObs
                && setDetailsTaxon( lifelist.detailsTaxon, { without_descendants: true } )}
            >
              <span className="attr">
                { I18n.t( "views.lifelists.observations_at_this_taxon" ) }
              </span>
              <span className="value">
                <Badge className="green">
                  { I18n.toNumber( lifelist.detailsTaxon.direct_obs_count, { precision: 0 } ) }
                </Badge>
              </span>
            </button>
            { isLeaf || descendantsStats }
          </div>
        );
      }
    } else {
      title = I18n.t( "views.lifelists.all_observations" );
      stats = (
        <div className="stats">
          <span className="stat">
            <span className="attr">
              { I18n.t( "views.lifelists.total_observations" ) }
            </span>
            <span className="value">
              { searchLoaded
                ? I18n.toNumber( inatAPIsearch.searchResponse.total_results, { precision: 0 } )
                : ( <div className="loading_spinner" /> ) }
            </span>
          </span>
        </div>
      );
    }
  } else if ( lifelist.detailsView === "species" ) {
    title = I18n.t( "views.lifelists.all_species" );
    inatAPIsearch = inatAPI.speciesPlace;
    const count = _.size( filteredNodes( lifelist, inatAPIsearch ) );
    searchLoaded = true;
    if ( lifelist.speciesPlaceFilter ) {
      searchLoaded = inatAPIsearch && inatAPIsearch.searchResponse;
    }
    // TODO iconic_taxon_name doesn't actually seem to be present on this
    // taxon, but we'll want it to be if we want this to be translated
    // properly in languages that have different rank names for different
    // groups
    stats = (
      <div className="stats">
        <span className="stat">
          <span className="attr">
            { I18n.t( "views.lifelists.observed_rank", {
              rank: rankLabel( { rank: lifelist.speciesViewRankFilter, withLeaves: false } ),
              iconic_taxon: lifelist.detailsTaxon?.iconic_taxon_name
            } ) }
          </span>
          <span className="value">
            { searchLoaded
              ? I18n.toNumber( count, { precision: 0 } )
              : ( <div className="loading_spinner" /> ) }
          </span>
        </span>
      </div>
    );
  } else if ( lifelist.detailsView === "unobservedSpecies" ) {
    title = I18n.t( "views.lifelists.all_unobserved_species" );
    inatAPIsearch = inatAPI.unobservedSpecies;
    searchLoaded = inatAPIsearch && inatAPIsearch.searchResponse;
    stats = (
      <div className="stats">
        <span className="stat">
          <span className="attr">
            { I18n.t( "views.lifelists.unobserved_species" ) }
          </span>
          <span className="value">
            { searchLoaded
              ? I18n.toNumber( inatAPIsearch.searchResponse.total_results, { precision: 0 } )
              : ( <div className="loading_spinner" /> ) }
          </span>
        </span>
      </div>
    );
  }
  const taxonClear = lifelist.detailsView === "unobservedSpecies" ? null : (
    <button
      type="button"
      className="nostyle"
      onClick={( ) => setDetailsTaxon( null )}
    >
      <span className="fa fa-times" />
    </button>
  );
  return (
    <div className="Details">
      { lifelist.detailsTaxon ? (
        <h3>
          { taxonClear }
          <SplitTaxon
            taxon={lifelist.detailsTaxon}
            url={`/taxa/${lifelist.detailsTaxon.id}`}
            noInactive
          />
        </h3>
      ) : (
        <h3>
          { title }
        </h3>
      )}
      { stats }
      <div className="search-options">
        <div className="place-search">
          <div className="icon-state">
            <span className="glyphicon glyphicon-map-marker ac-select-thumb" />
            { lifelist.speciesPlaceFilter
              ? I18n.t( "views.lifelists.filtered_by" )
              : I18n.t( "views.lifelists.filter_by" ) }
          </div>
          { lifelist.speciesPlaceFilter ? (
            <Badge>
              { lifelist.speciesPlaceFilter.display_name }
              <button
                type="button"
                className="clear"
                onClick={( ) => setSpeciesPlaceFilter( null )}
              >
                &times;
              </button>
            </Badge>
          ) : (
            <PlaceAutocomplete
              resetOnChange={false}
              initialPlaceID={lifelist.speciesPlaceFilter}
              bootstrapClear
              afterSelect={result => {
                setSpeciesPlaceFilter( result.item );
              }}
              afterUnselect={( ) => {
                setSpeciesPlaceFilter( null );
              }}
            />
          ) }
        </div>
      </div>
      { searchOptions }
      { view }
    </div>
  );
};

DetailsView.propTypes = {
  lifelist: PropTypes.object,
  inatAPI: PropTypes.object,
  setDetailsTaxon: PropTypes.func,
  setSpeciesPlaceFilter: PropTypes.func,
  setObservationSort: PropTypes.func
};

export default DetailsView;
