/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */
/* eslint react/destructuring-assignment: 0 */
import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Badge } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

class TaxaList extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.showNode = this.showNode.bind( this );
  }

  showNode( taxon, isChild ) {
    const {
      lifelist, openTaxon, detailsTaxon, setDetailsTaxon,
      config, setDetailsView, setListViewOpenTaxon
    } = this.props;
    const parentElements = [];
    if ( taxon && !isChild ) {
      if ( taxon.parent_id === 0 ) {
        parentElements.push( this.showNode( null ) );
      } else {
        parentElements.push( this.showNode( lifelist.taxa[taxon.parent_id] ) );
      }
    }
    const isLeaf = taxon && !lifelist.children[taxon.id];
    const nameClasses = ["name-label"];
    if ( detailsTaxon && taxon && detailsTaxon.id === taxon.id ) {
      nameClasses.push( "featured" );
    }
    if ( detailsTaxon && taxon
      && taxon.left < detailsTaxon.left
      && taxon.right > detailsTaxon.right ) {
      nameClasses.push( "featured-ancestor" );
    }
    const descendantObsCount = taxon ? taxon.descendant_obs_count : lifelist.observationsCount;
    const directObsCount = taxon ? taxon.direct_obs_count : lifelist.observationsWithoutTaxon;
    return parentElements.concat( [(
      <li
        className={`${isChild ? "child" : ""}`}
        key={`branch-${taxon ? taxon.id : 0}`}
      >
        <div className="name-row">
          <div
            className={nameClasses.join( " " )}
            onClick={( ) => setListViewOpenTaxon( taxon )}
          >
            { taxon ? (
              <SplitTaxon
                taxon={taxon}
                key={`${taxon.name}-${taxon.preferred_common_name}`}
                user={config.currentUser}
              />
            ) : (
              <div className="name-label featured-ancestor">
                Life
              </div>
            ) }
          </div>
          { ( !( isLeaf && taxon && taxon.rank_level > 10 ) && descendantObsCount ) ? (
            <span
              className="descendants"
              onClick={( ) => setDetailsTaxon( taxon )}
              title="All observations in this taxon"
            >
              { descendantObsCount }
            </span>
          ) : null }
          { !( isLeaf && taxon && taxon.rank_level <= 10 ) && directObsCount ? (
            <Badge
              className="green"
              onClick={( ) => {
                setDetailsTaxon( taxon, { without_descendants: true } );
                setDetailsView( "observations" );
              }}
              title="Observations of exactly this taxon"
            >
              { directObsCount }
            </Badge>
          ) : null }
          <span
            className={`${lifelist.detailsView === "observations" ? "icon icon-binoculars" : "fa fa-leaf"}`}
            onClick={( ) => {
              setDetailsTaxon( taxon );
              if ( lifelist.detailsView === "observations" ) {
                setDetailsView( "observations" );
              } else {
                setDetailsView( "species" );
              }
            }}
            title={`${lifelist.detailsView === "observations" ? "View observations" : "View speciews"}`}
          />
        </div>
        { taxon === openTaxon && this.secondaryNodeList( ) }
      </li>
    )] );
  }

  secondaryNodeList( ) {
    const { lifelist, openTaxon, setListViewScrollPage } = this.props;
    let nodeShouldDisplay;
    const nodeIsDescendant = !openTaxon
      ? ( ) => true
      : node => node.left > openTaxon.left && node.right < openTaxon.right;
    if ( lifelist.listViewRankFilter === "all" ) {
      if ( openTaxon ) {
        nodeShouldDisplay = node => node.left > openTaxon.left && node.right < openTaxon.right;
      } else {
        nodeShouldDisplay = nodeIsDescendant;
      }
    } else if ( lifelist.listViewRankFilter === "children" ) {
      nodeShouldDisplay = node => node.parent_id === ( openTaxon ? openTaxon.id : 0 );
    } else if ( lifelist.listViewRankFilter === "major" ) {
      nodeShouldDisplay = node => node.rank_level % 10 === 0;
    } else if ( lifelist.listViewRankFilter === "kingdoms" ) {
      nodeShouldDisplay = node => node.rank_level === 70;
    } else if ( lifelist.listViewRankFilter === "phylums" ) {
      nodeShouldDisplay = node => node.rank_level === 60;
    } else if ( lifelist.listViewRankFilter === "classes" ) {
      nodeShouldDisplay = node => node.rank_level === 50;
    } else if ( lifelist.listViewRankFilter === "orders" ) {
      nodeShouldDisplay = node => node.rank_level === 40;
    } else if ( lifelist.listViewRankFilter === "families" ) {
      nodeShouldDisplay = node => node.rank_level === 30;
    } else if ( lifelist.listViewRankFilter === "genera" ) {
      nodeShouldDisplay = node => node.rank_level === 20;
    } else if ( lifelist.listViewRankFilter === "species" ) {
      nodeShouldDisplay = node => node.rank_level === 10;
    } else if ( lifelist.listViewRankFilter === "leaves" ) {
      nodeShouldDisplay = node => node.left === node.right - 1;
    }
    if ( !nodeShouldDisplay ) return null;
    const secondaryNodes = _.filter( lifelist.taxa,
      t => nodeIsDescendant( t ) && nodeShouldDisplay( t ) );
    let moreButton;
    if ( lifelist.listViewScrollPage < (
      Math.ceil( _.size( secondaryNodes ) ) / lifelist.listViewPerPage ) ) {
      moreButton = (
        <button
          type="button"
          className="btn btn-sm btn-default"
          onClick={( ) => {
            setListViewScrollPage( lifelist.listViewScrollPage + 1 );
          }}
        >
          <i className="fa fa-caret-down" />
          Show More
        </button>
      );
    }
    let sortMethod;
    if ( lifelist.listViewSort === "name" ) {
      sortMethod = t => t.name;
    } else if ( lifelist.listViewSort === "taxonomic" ) {
      sortMethod = t => t.left;
    } else {
      sortMethod = t => -1 * t.descendant_obs_count;
    }
    const secondaryNodesToDisplay = _.slice( _.sortBy( secondaryNodes, sortMethod ), 0,
      lifelist.listViewScrollPage * lifelist.listViewPerPage );
    return (
      <div>
        <ul className="children">
          { _.map( secondaryNodesToDisplay, t => this.showNode( t, true ) ) }
        </ul>
        <div className="more">
          { moreButton }
        </div>
      </div>
    );
  }

  render( ) {
    const {
      lifelist, openTaxon, setListViewRankFilter, setListViewSort
    } = this.props;
    if ( !lifelist.taxa || !lifelist.children ) { return ( <span /> ); }
    let rankLabel = "Show: Children";
    if ( lifelist.listViewRankFilter === "all" ) {
      rankLabel = "Show: All ranks";
    } else if ( lifelist.listViewRankFilter === "major" ) {
      rankLabel = "Show: Major Ranks";
    } else if ( lifelist.listViewRankFilter === "kingdoms" ) {
      rankLabel = "Show: Kingdoms";
    } else if ( lifelist.listViewRankFilter === "phylums" ) {
      rankLabel = "Show: Phylums";
    } else if ( lifelist.listViewRankFilter === "classes" ) {
      rankLabel = "Show: Classes";
    } else if ( lifelist.listViewRankFilter === "orders" ) {
      rankLabel = "Show: Orders";
    } else if ( lifelist.listViewRankFilter === "families" ) {
      rankLabel = "Show: Families";
    } else if ( lifelist.listViewRankFilter === "genera" ) {
      rankLabel = "Show: Genera";
    } else if ( lifelist.listViewRankFilter === "species" ) {
      rankLabel = "Show: Species";
    } else if ( lifelist.listViewRankFilter === "leaves" ) {
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
            className={lifelist.listViewRankFilter === "children" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "children" )}
          >
            Children
          </li>
          <li
            className={lifelist.listViewRankFilter === "all" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "all" )}
          >
            All ranks
          </li>
          <li
            className={lifelist.listViewRankFilter === "major" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "major" )}
          >
            Major Ranks
          </li>
          { [{ filter: "kingdoms", label: "Kingdoms", rank_level: 70 },
            { filter: "phylums", label: "Phylums", rank_level: 60 },
            { filter: "classes", label: "Classes", rank_level: 50 },
            { filter: "orders", label: "Orders", rank_level: 40 },
            { filter: "families", label: "Families", rank_level: 30 },
            { filter: "genera", label: "Genera", rank_level: 20 },
            { filter: "species", label: "Species", rank_level: 10 }].map( r => (
              <li
                disabled={openTaxon && openTaxon.rank_level <= r.rank_level}
                className={lifelist.listViewRankFilter === r.filter ? "selected" : null}
                key={`rank-filter-${r.filter}`}
                onClick={e => {
                  if ( openTaxon && openTaxon.rank_level <= r.rank_level ) {
                    e.preventDefault( );
                    e.stopPropagation( );
                    return;
                  }
                  setListViewRankFilter( r.filter );
                }}
              >
                { r.label }
              </li>
          ) )}
          <li
            className={lifelist.listViewRankFilter === "leaves" ? "selected" : null}
            onClick={( ) => setListViewRankFilter( "leaves" )}
          >
            Leaves
          </li>
        </ul>
      </div>
    );
    let sortLabel = "Sort: Total Observations";
    if ( lifelist.listViewSort === "name" ) {
      sortLabel = "Sort: Name";
    } else if ( lifelist.listViewSort === "taxonomic" ) {
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
            className={lifelist.listViewSort === "obsDesc" ? "selected" : null}
            onClick={( ) => setListViewSort( "obsDesc" )}
          >
            Total Observations
          </li>
          <li
            className={lifelist.listViewSort === "name" ? "selected" : null}
            onClick={( ) => setListViewSort( "name" )}
          >
            Name
          </li>
          <li
            className={lifelist.listViewSort === "taxonomic" ? "selected" : null}
            onClick={( ) => setListViewSort( "taxonomic" )}
          >
            Taxonomic
          </li>
        </ul>
      </div>
    );
    return (
      <div className="Details">
        <div className="search-options">
          { sortOptions }
          { rankOptions }
        </div>
        <div id="TaxaList">
          <ul className="list">
            { this.showNode( openTaxon ) }
          </ul>
        </div>
      </div>
    );
  }
}

TaxaList.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  openTaxon: PropTypes.object,
  detailsTaxon: PropTypes.object,
  setDetailsTaxon: PropTypes.func,
  setDetailsView: PropTypes.func,
  setListViewScrollPage: PropTypes.func,
  setListViewSort: PropTypes.func,
  setListViewRankFilter: PropTypes.func,
  setListViewOpenTaxon: PropTypes.func
};

export default TaxaList;
