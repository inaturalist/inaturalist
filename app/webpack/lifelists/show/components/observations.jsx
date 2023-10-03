import _ from "lodash";
import React, { Component } from "react";
import { DropdownButton, MenuItem } from "react-bootstrap";
import PropTypes from "prop-types";
import Observation from "../../../projects/show/components/observation";

// eslint-disable-next-line react/prefer-stateless-function
class Observations extends Component {
  render( ) {
    const {
      lifelist, search, fetchNextPage, config, setSpeciesPlaceFilter, setObservationSort
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
        emptyMessage = I18n.t( "views.lifelists.no_observations_found_within_this_taxon_in_place", {
          place: lifelist.speciesPlaceFilter.display_name
        } );
      } else {
        emptyMessage = I18n.t( "views.lifelists.no_observations_found_in_place", {
          place: lifelist.speciesPlaceFilter.display_name
        } );
      }
      emptyClearButton = (
        <button
          type="button"
          className="btn btn-primary"
          onClick={( ) => setSpeciesPlaceFilter( null )}
        >
          { I18n.t( "views.lifelists.reset_place_filter" ) }
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
            config={config}
            hideUserIcon
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
              { I18n.t( "show_more" ) }
            </button>
          </div>
        );
    }
    let label = lifelist.observationSort === "dateAsc"
      ? I18n.t( "views.lifelists.dropdowns.date_added_oldest" )
      : I18n.t( "views.lifelists.dropdowns.date_added_newest" );
    label = `${I18n.t( "views.lifelists.dropdowns.sort" )}: ${label}`;
    const sortOptions = (
      <DropdownButton
        title={label}
        id="obsSortDropdown"
        onSelect={key => setObservationSort( key )}
      >
        <MenuItem
          eventKey="dateDesc"
          className={lifelist.observationSort === "dateDesc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.date_added_newest" ) }
        </MenuItem>
        <MenuItem
          eventKey="dateAsc"
          className={lifelist.observationSort === "dateAsc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.date_added_oldest" ) }
        </MenuItem>
      </DropdownButton>
    );
    return (
      <div className="Details">
        <div className="search-options">
          { sortOptions }
        </div>
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
  setSpeciesPlaceFilter: PropTypes.func,
  setObservationSort: PropTypes.func
};

export default Observations;
