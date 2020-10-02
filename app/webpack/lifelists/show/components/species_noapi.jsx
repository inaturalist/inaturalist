import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

class SpeciesNoAPI extends Component {
  secondaryNodeList( ) {
    const {
      lifelist, detailsTaxon, setScrollPage, config, zoomToTaxon,
      search, setSpeciesPlaceFilter
    } = this.props;
    let nodeShouldDisplay;
    const nodeIsDescendant = ( !detailsTaxon || detailsTaxon === "root" )
      ? ( ) => true
      : node => node.left >= detailsTaxon.left && node.right <= detailsTaxon.right;
    const obsCount = node => {
      if ( lifelist.speciesPlaceFilter
          && search
          && search.searchResponse
          && search.loaded
      ) {
        return search.searchResponse.results[node.id] || 0;
      }
      return node.descendant_obs_count;
    };
    if ( lifelist.speciesViewRankFilter === "all" ) {
      if ( !detailsTaxon || detailsTaxon === "root" ) {
        nodeShouldDisplay = nodeIsDescendant;
      } else {
        nodeShouldDisplay = node => (
          ( detailsTaxon.left === detailsTaxon.right - 1 && node.id === detailsTaxon.id )
          || ( node.left > detailsTaxon.left && node.right < detailsTaxon.right )
        );
      }
    } else if ( lifelist.speciesViewRankFilter === "children" ) {
      nodeShouldDisplay = node => node.parent_id === ( !detailsTaxon || detailsTaxon === "root" ? 0 : detailsTaxon.id );
    } else if ( lifelist.speciesViewRankFilter === "major" ) {
      nodeShouldDisplay = node => node.rank_level % 10 === 0;
    } else if ( lifelist.speciesViewRankFilter === "kingdoms" ) {
      nodeShouldDisplay = node => node.rank_level === 70;
    } else if ( lifelist.speciesViewRankFilter === "phyla" ) {
      nodeShouldDisplay = node => node.rank_level === 60;
    } else if ( lifelist.speciesViewRankFilter === "classes" ) {
      nodeShouldDisplay = node => node.rank_level === 50;
    } else if ( lifelist.speciesViewRankFilter === "orders" ) {
      nodeShouldDisplay = node => node.rank_level === 40;
    } else if ( lifelist.speciesViewRankFilter === "families" ) {
      nodeShouldDisplay = node => node.rank_level === 30;
    } else if ( lifelist.speciesViewRankFilter === "genera" ) {
      nodeShouldDisplay = node => node.rank_level === 20;
    } else if ( lifelist.speciesViewRankFilter === "species" ) {
      nodeShouldDisplay = node => node.rank_level === 10;
    } else if ( lifelist.speciesViewRankFilter === "leaves" ) {
      nodeShouldDisplay = node => (
        node.rank_level === 10 || (
          node.left === node.right - 1 && node.rank_level > 10
        ) || (
          detailsTaxon && detailsTaxon.rank_level < 10 && detailsTaxon.id === node.id
        )
      );
    }
    if ( !nodeShouldDisplay ) return null;
    const secondaryNodes = _.filter( lifelist.taxa,
      t => nodeIsDescendant( t ) && nodeShouldDisplay( t ) && obsCount( t ) );
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
      <div className="SpeciesGrid" key={`grid-${lifelist.speciesViewRankFilter}-${lifelist.speciesPlaceFilter && lifelist.speciesPlaceFilter.id}-${detailsTaxon && detailsTaxon.id}`}>
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
            <div className="result" key={`grid_taxon_${s.id}`}>
              <TaxonThumbnail
                taxon={s}
                config={config}
                truncate={null}
                height={210}
                noInactive
                onClick={onClick}
                overlay={(
                  <div>
                    <a
                      onClick={onClick}
                      href={`/observations?user_id=${lifelist.user.login}&taxon_id=${s.id}&place_id=any&verifiable=any`}
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
    let rankLabel = I18n.t( "views.lifelists.dropdowns.children" );
    if ( lifelist.speciesViewRankFilter === "kingdoms" ) {
      rankLabel = I18n.t( "ranks.x_kingdoms", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "phyla" ) {
      rankLabel = I18n.t( "ranks.x_phyla", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "classes" ) {
      rankLabel = I18n.t( "ranks.x_classes", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "orders" ) {
      rankLabel = I18n.t( "ranks.x_orders", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "families" ) {
      rankLabel = I18n.t( "ranks.x_families", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "genera" ) {
      rankLabel = I18n.t( "ranks.x_genera", { count: 2 } );
    } else if ( lifelist.speciesViewRankFilter === "species" ) {
      rankLabel = I18n.t( "ranks.species" );
    } else if ( lifelist.speciesViewRankFilter === "leaves" ) {
      rankLabel = I18n.t( "ranks.leaves" );
    }
    rankLabel = `${I18n.t( "views.lifelists.dropdowns.show" )}: ${rankLabel}`;
    const rankOptions = (
      <div className="dropdown">
        <button
          className="btn btn-sm dropdown-toggle"
          type="button"
          data-toggle="dropdown"
          id="rankDropdown"
        >
          { rankLabel }
          <span className="caret" />
        </button>
        <ul className="dropdown-menu" aria-labelledby="rankDropdown">
          <li
            className={lifelist.speciesViewRankFilter === "children" ? "selected" : null}
            onClick={( ) => setRankFilter( "children" )}
            disabled={detailsTaxon && detailsTaxon.right === detailsTaxon.left + 1}
          >
            Children
          </li>
          { [{ filter: "kingdoms", rank_level: 70 },
            { filter: "phyla", rank_level: 60 },
            { filter: "classes", rank_level: 50 },
            { filter: "orders", rank_level: 40 },
            { filter: "families", rank_level: 30 },
            { filter: "genera", rank_level: 20 },
            { filter: "species", rank_level: 10 }].map( r => (
              <li
                key={`rank-filter-${r.filter}`}
                disabled={detailsTaxon && ( detailsTaxon.rank_level <= 20 || detailsTaxon.rank_level <= r.rank_level )}
                className={lifelist.speciesViewRankFilter === r.filter ? "selected" : null}
                onClick={e => {
                  if ( detailsTaxon && detailsTaxon.rank_level <= r.rank_level ) {
                    e.preventDefault( );
                    e.stopPropagation( );
                    return;
                  }
                  setRankFilter( r.filter );
                }}
              >
                { I18n.t( `ranks.x_${r.filter}`, { count: 2 } ) }
              </li>
          ) )}
          <li
            className={lifelist.speciesViewRankFilter === "leaves" ? "selected" : null}
            onClick={( ) => setRankFilter( "leaves" )}
          >
            { I18n.t( "ranks.leaves" ) }
          </li>
        </ul>
      </div>
    );
    let sortLabel = I18n.t( "views.lifelists.dropdowns.most_observed" );
    if ( lifelist.speciesViewSort === "name" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.name" );
    } else if ( lifelist.speciesViewSort === "taxonomic" ) {
      sortLabel = I18n.t( "views.lifelists.dropdowns.taxonomic" );
    }
    sortLabel = `${I18n.t( "views.lifelists.dropdowns.sort" )}: ${sortLabel}`;
    const sortOptions = (
      <div className="dropdown">
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
            className={lifelist.speciesViewSort === "obsDesc" ? "selected" : null}
            onClick={( ) => setSort( "obsDesc" )}
          >
            { I18n.t( "views.lifelists.dropdowns.most_observed" ) }
          </li>
          <li
            className={lifelist.speciesViewSort === "name" ? "selected" : null}
            onClick={( ) => setSort( "name" )}
          >
            { I18n.t( "views.lifelists.dropdowns.name" ) }
          </li>
          <li
            className={lifelist.speciesViewSort === "taxonomic" ? "selected" : null}
            onClick={( ) => setSort( "taxonomic" )}
          >
            { I18n.t( "views.lifelists.dropdowns.taxonomic" ) }
          </li>
        </ul>
      </div>
    );
    const loading = ( lifelist.speciesPlaceFilter && ( !search || ( !search.searchResponse && !search.loaded ) ) );
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
