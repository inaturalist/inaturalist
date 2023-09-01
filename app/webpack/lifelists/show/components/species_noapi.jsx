import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import { DropdownButton, MenuItem } from "react-bootstrap";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";
import { rankLabel, filteredNodes, nodeObsCount } from "../util";

class SpeciesNoAPI extends Component {
  secondaryNodeList( ) {
    const {
      lifelist, detailsTaxon, setScrollPage, config, zoomToTaxon, setSpeciesPlaceFilter, search
    } = this.props;
    const obsCount = nodeObsCount( lifelist, search );
    const secondaryNodes = filteredNodes( lifelist, search );
    let moreButton;
    if ( lifelist.speciesViewScrollPage < (
      Math.ceil( _.size( secondaryNodes ) ) / lifelist.speciesViewPerPage ) ) {
      moreButton = (
        <div className="more" key={`more-${lifelist.speciesViewScrollPage}`}>
          <button
            type="button"
            className="btn btn-sm btn-default"
            onClick={( ) => {
              setScrollPage( lifelist.speciesViewScrollPage + 1 );
            }}
          >
            <i className="fa fa-caret-down" />
            { I18n.t( "show_more" ) }
          </button>
        </div>
      );
    }
    let sortMethod;
    if ( lifelist.speciesViewSort === "name" ) {
      sortMethod = t => t.name;
    } else if ( lifelist.speciesViewSort === "taxonomic" ) {
      sortMethod = t => t.left;
    } else if ( lifelist.speciesViewSort === "obsAsc" ) {
      sortMethod = [t => obsCount( t ), "left"];
    } else {
      sortMethod = [t => -1 * obsCount( t ), "left"];
    }
    const secondaryNodesToDisplay = _.slice( _.sortBy( secondaryNodes, sortMethod ), 0,
      lifelist.speciesViewScrollPage * lifelist.speciesViewPerPage );
    let emptyMessage;
    let emptyClearButton;
    if ( _.size( secondaryNodesToDisplay ) === 0 && lifelist.speciesPlaceFilter ) {
      if ( lifelist.detailsTaxon ) {
        emptyMessage = I18n.t( "views.lifelists.no_species_found_within_this_taxon_in_place", {
          place: lifelist.speciesPlaceFilter.display_name
        } );
      } else {
        emptyMessage = I18n.t( "views.lifelists.no_species_found_in_place", {
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
    }
    return (
      <div
        className="SpeciesGrid"
        key={`grid-${lifelist.speciesViewRankFilter}-${
          lifelist.speciesPlaceFilter && lifelist.speciesPlaceFilter.id}-${
          detailsTaxon && detailsTaxon.id}`}
      >
        { emptyMessage && (
          <div className="empty">
            { emptyMessage }
            { emptyClearButton }
          </div>
        ) }
        { _.map( secondaryNodesToDisplay, s => {
          const onClick = e => {
            if ( zoomToTaxon ) {
              e.preventDefault( );
              zoomToTaxon( s.id, { detailsView: "observations" } );
            }
          };
          return (
            <div className="result d-flex" key={`grid_taxon_${s.id}`}>
              <TaxonThumbnail
                className="flex-grow-1"
                taxon={s}
                config={config}
                height={210}
                noInactive
                onClick={onClick}
                overlay={(
                  <div>
                    <a
                      onClick={onClick}
                      href={`/observations?user_id=${lifelist.user.login}&taxon_id=${
                        s.id}&place_id=any&verifiable=any`}
                    >
                      { I18n.t( "x_observations", { count: obsCount( s ) } ) }
                    </a>
                  </div>
                )}
              />
            </div>
          );
        } ) }
        { moreButton }
      </div>
    );
  }

  render( ) {
    const {
      lifelist, detailsTaxon, setRankFilter, setSort, search
    } = this.props;
    if ( !lifelist.taxa || !lifelist.children ) { return ( <span /> ); }

    const rankOptions = (
      <DropdownButton
        title={`${I18n.t( "views.lifelists.dropdowns.show" )}: ${rankLabel(
          { rank: lifelist.speciesViewRankFilter }
        )}`}
        id="rankDropdown"
        onSelect={key => setRankFilter( key )}
      >
        <MenuItem
          eventKey="children"
          className={lifelist.speciesViewRankFilter === "children" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.children" ) }
        </MenuItem>
        { [{ filter: "kingdoms", rank_level: 70 },
          { filter: "phyla", rank_level: 60 },
          { filter: "classes", rank_level: 50 },
          { filter: "orders", rank_level: 40 },
          { filter: "families", rank_level: 30 },
          { filter: "genera", rank_level: 20 },
          { filter: "species", rank_level: 10 }].map( r => (
            <MenuItem
              key={`rankFilter-${r.filter}`}
              eventKey={r.filter}
              disabled={detailsTaxon
                && ( detailsTaxon.rank_level <= 20 || detailsTaxon.rank_level <= r.rank_level )}
              className={lifelist.speciesViewRankFilter === r.filter ? "selected" : null}
            >
              { I18n.t( `ranks.x_${r.filter}`, { count: 2 } ) }
            </MenuItem>
        ) )}
        <MenuItem
          eventKey="leaves"
          className={lifelist.speciesViewRankFilter === "leaves" ? "selected" : null}
        >
          { I18n.t( "ranks.leaves" ) }
        </MenuItem>
      </DropdownButton>
    );
    let sortLabel = I18n.t( "views.lifelists.dropdowns.most_observed" );
    if ( lifelist.speciesViewSort === "name" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.name" );
    } else if ( lifelist.speciesViewSort === "taxonomic" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.taxonomic" );
    } else if ( lifelist.speciesViewSort === "obsAsc" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.least_observed" );
    }
    sortLabel = `${I18n.t( "views.lifelists.dropdowns.sort" )}: ${sortLabel}`;
    const sortOptions = (
      <DropdownButton
        title={sortLabel}
        id="speciesSortDropdown"
        onSelect={key => setSort( key )}
      >
        <MenuItem
          eventKey="obsDesc"
          className={lifelist.speciesViewSort === "obsDesc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.most_observed" ) }
        </MenuItem>
        <MenuItem
          eventKey="obsAsc"
          className={lifelist.speciesViewSort === "obsAsc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.least_observed" ) }
        </MenuItem>
        <MenuItem
          eventKey="name"
          className={lifelist.speciesViewSort === "name" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.name" ) }
        </MenuItem>
        <MenuItem
          eventKey="taxonomic"
          className={lifelist.speciesViewSort === "taxonomic" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.taxonomic" ) }
        </MenuItem>
      </DropdownButton>
    );
    const loading = ( lifelist.speciesPlaceFilter
      && ( !search || ( !search.searchResponse && !search.loaded ) ) );
    let view;
    if ( loading ) {
      view = ( <div className="loading_spinner huge" /> );
    } else {
      view = this.secondaryNodeList( );
    }
    return (
      <div className="Details">
        <div className="search-options">
          { sortOptions }
          { rankOptions }
        </div>
        { view }
      </div>
    );
  }
}

SpeciesNoAPI.propTypes = {
  config: PropTypes.object,
  search: PropTypes.object,
  lifelist: PropTypes.object,
  detailsTaxon: PropTypes.object,
  setSpeciesPlaceFilter: PropTypes.func,
  setScrollPage: PropTypes.func,
  setSort: PropTypes.func,
  setRankFilter: PropTypes.func,
  zoomToTaxon: PropTypes.func
};

export default SpeciesNoAPI;
