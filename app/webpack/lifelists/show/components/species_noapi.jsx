import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import TaxonThumbnail from "../../../taxa/show/components/taxon_thumbnail";

class SpeciesNoAPI extends Component {
  constructor( props, context ) {
    super( props, context );
    let asdf = "ASdf";
  }

  secondaryNodeList( ) {
    const {
      lifelist, detailsTaxon, setScrollPage, config, zoomToTaxon, search
    } = this.props;
    let nodeShouldDisplay;
    const nodeIsDescendant = ( !detailsTaxon || detailsTaxon === "root" )
      ? ( ) => true
      : node => node.left >= detailsTaxon.left && node.right <= detailsTaxon.right;
    const nodeIsInPlace = node => {
      if ( lifelist.speciesPlaceFilter
          && search
          && search.searchResponse
          && search.loaded
          && !_.includes( search.searchResponse.results, node.id ) ) {
        return false;
      }
      return true;
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
    } else if ( lifelist.speciesViewRankFilter === "phylums" ) {
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
      nodeShouldDisplay = node => node.left === node.right - 1;
    }
    if ( !nodeShouldDisplay ) return null;
    const secondaryNodes = _.filter( lifelist.taxa,
      t => nodeIsDescendant( t ) && nodeShouldDisplay( t ) && nodeIsInPlace( t ) );
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
            Show More
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
      sortMethod = [t => -1 * t.descendant_obs_count, "left"];
    }
    const secondaryNodesToDisplay = _.slice( _.sortBy( secondaryNodes, sortMethod ), 0,
      lifelist.speciesViewScrollPage * lifelist.speciesViewPerPage );
    return (
      <div className="SpeciesGrid" key={`grid-${lifelist.speciesViewRankFilter}-${lifelist.speciesPlaceFilter}-${detailsTaxon && detailsTaxon.id}`}>
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
                      { I18n.t( "x_observations", { count: s.descendant_obs_count } ) }
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
    let rankLabel = "Show: Children";
    if ( lifelist.speciesViewRankFilter === "kingdoms" ) {
      rankLabel = "Show: Kingdoms";
    } else if ( lifelist.speciesViewRankFilter === "phylums" ) {
      rankLabel = "Show: Phylums";
    } else if ( lifelist.speciesViewRankFilter === "classes" ) {
      rankLabel = "Show: Classes";
    } else if ( lifelist.speciesViewRankFilter === "orders" ) {
      rankLabel = "Show: Orders";
    } else if ( lifelist.speciesViewRankFilter === "families" ) {
      rankLabel = "Show: Families";
    } else if ( lifelist.speciesViewRankFilter === "genera" ) {
      rankLabel = "Show: Genera";
    } else if ( lifelist.speciesViewRankFilter === "species" ) {
      rankLabel = "Show: Species";
    } else if ( lifelist.speciesViewRankFilter === "leaves" ) {
      rankLabel = "Show: Leaves";
    }
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
          >
            Children
          </li>
          { [{ filter: "kingdoms", label: "Kingdoms", rank_level: 70 },
            { filter: "phylums", label: "Phylums", rank_level: 60 },
            { filter: "classes", label: "Classes", rank_level: 50 },
            { filter: "orders", label: "Orders", rank_level: 40 },
            { filter: "families", label: "Families", rank_level: 30 },
            { filter: "genera", label: "Genera", rank_level: 20 },
            { filter: "species", label: "Species", rank_level: 10 }].map( r => (
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
                { r.label }
              </li>
          ) )}
          <li
            className={lifelist.speciesViewRankFilter === "leaves" ? "selected" : null}
            onClick={( ) => setRankFilter( "leaves" )}
          >
            Leaves
          </li>
        </ul>
      </div>
    );
    let sortLabel = "Sort: Total Observations";
    if ( lifelist.speciesViewSort === "name" ) {
      sortLabel = "Sort: Name";
    } else if ( lifelist.speciesViewSort === "taxonomic" ) {
      sortLabel = "Sort: Taxonomic";
    }
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
            Total Observations
          </li>
          <li
            className={lifelist.speciesViewSort === "name" ? "selected" : null}
            onClick={( ) => setSort( "name" )}
          >
            Name
          </li>
          <li
            className={lifelist.speciesViewSort === "taxonomic" ? "selected" : null}
            onClick={( ) => setSort( "taxonomic" )}
          >
            Taxonomic
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
  setScrollPage: PropTypes.func,
  setSort: PropTypes.func,
  setRankFilter: PropTypes.func,
  zoomToTaxon: PropTypes.func
};

export default SpeciesNoAPI;
