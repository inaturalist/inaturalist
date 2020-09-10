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
    const sortLabel = lifelist.observationSort === "dateAsc"
      ? "Sort by: Date added, oldest to newest"
      : "Sort by: Date added, newest to oldest";
    searchOptions = (
      <div className="dropdown sortDropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="sortDropdown"
        >
          { sortLabel }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="sortDropdown">
          <li
            className={lifelist.observationSort === "dateDesc" ? "selected" : null}
            onClick={( ) => setObservationSort( "dateDesc" )}
          >
            Date: Newest to oldest
          </li>
          <li
            className={lifelist.observationSort === "dateAsc" ? "selected" : null}
            onClick={( ) => setObservationSort( "dateAsc" )}
          >
            Date: Oldest to newest
          </li>
        </ul>
      </div>
    );
    view = (
      <ObservationsGridContainer
        lifelist={lifelist}
        setSpeciesPlaceFilter={setSpeciesPlaceFilter}
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
        const label = isLeaf ? "Observations at this taxon:" : "Observations within this taxon:";
        stats = (
          <div className="stats">
            <span className="stat">
              <span className="attr">{label}</span>
              <span className="value">
                { searchLoaded
                  ? inatAPIsearch.searchResponse.total_results.toLocaleString( )
                  : ( <div className="loading_spinner" /> ) }
              </span>
            </span>
          </div>
        );
      } else {
        const hasDirectObs = lifelist.detailsTaxon.direct_obs_count > 0;
        const hasDescendantObs = lifelist.detailsTaxon.descendant_obs_count > 0;
        const descendantsStats = (
          <span
            className={`stat ${lifelist.detailsTaxonExact ? "" : "selected "}${hasDescendantObs ? "clicky" : ""}`}
            onClick={( ) => hasDescendantObs && setDetailsTaxon( lifelist.detailsTaxon )}
          >
            <span className="attr">Observations within this taxon:</span>
            <span className="value">
              { lifelist.detailsTaxon.descendant_obs_count.toLocaleString( ) }
            </span>
          </span>
        );
        stats = (
          <div className="stats">
            <span
              className={`stat ${isLeaf || lifelist.detailsTaxonExact ? "selected " : ""}${hasDirectObs ? "clicky" : ""}`}
              onClick={( ) => hasDirectObs && setDetailsTaxon( lifelist.detailsTaxon, { without_descendants: true } )}
            >
              <span className="attr">Observations at this taxon:</span>
              <span className="value">
                <Badge className="green">
                  { lifelist.detailsTaxon.direct_obs_count.toLocaleString( ) }
                </Badge>
              </span>
            </span>
            { isLeaf || descendantsStats }
          </div>
        );
      }
    } else {
      title = "All Observations";
      stats = (
        <div className="stats">
          <span className="stat">
            <span className="attr">Total Observations:</span>
            <span className="value">
              { searchLoaded
                ? inatAPIsearch.searchResponse.total_results.toLocaleString( )
                : ( <div className="loading_spinner" /> ) }
            </span>
          </span>
        </div>
      );
    }
  } else if ( lifelist.detailsView === "species" ) {
    title = "All Species";
    let count = lifelist.detailsTaxon
      ? lifelist.detailsTaxon.descendantCount : lifelist.leavesCount;
    searchLoaded = true;
    if ( lifelist.speciesPlaceFilter ) {
      inatAPIsearch = inatAPI.speciesPlace;
      searchLoaded = inatAPIsearch && inatAPIsearch.searchResponse;
      if ( searchLoaded ) {
        const nodeIsDescendant = ( !lifelist.detailsTaxon || lifelist.detailsTaxon === "root" )
          ? ( ) => true
          : node => node.left >= lifelist.detailsTaxon.left
            && node.right <= lifelist.detailsTaxon.right;
        count = _.size( _.filter( lifelist.taxa, t => (
          nodeIsDescendant( t ) && (
            ( t.right === t.left + 1 )
              && inatAPIsearch.searchResponse.results[t.id]
          )
        ) ) );
      }
    }
    stats = (
      <div className="stats">
        <span className="stat">
          <span className="attr">Observed Species:</span>
          <span className="value">
            { searchLoaded
              ? count.toLocaleString( )
              : ( <div className="loading_spinner" /> ) }
          </span>
        </span>
      </div>
    );
  } else if ( lifelist.detailsView === "unobservedSpecies" ) {
    title = "All Unobserved Species";
    inatAPIsearch = inatAPI.unobservedSpecies;
    searchLoaded = inatAPIsearch && inatAPIsearch.searchResponse;
    stats = (
      <div className="stats">
        <span className="stat">
          <span className="attr">Unobserved Species:</span>
          <span className="value">
            { searchLoaded
              ? inatAPIsearch.searchResponse.total_results.toLocaleString( )
              : ( <div className="loading_spinner" /> ) }
          </span>
        </span>
      </div>
    );
  }
  const taxonClear = lifelist.detailsView === "unobservedSpecies" ? null : (
    <span
      className="fa fa-times"
      onClick={( ) => setDetailsTaxon( null )}
    />
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
            { lifelist.speciesPlaceFilter ? "Filtered by" : "Filter by" }
          </div>
          { lifelist.speciesPlaceFilter ? (
            <Badge>
              { lifelist.speciesPlaceFilter.display_name }
              <span
                className="clear"
                onClick={( ) => setSpeciesPlaceFilter( null ) }
              >
                &times;
              </span>
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
        { lifelist.detailsView !== "observations" && ( searchOptions ) }
      </div>
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
