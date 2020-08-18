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
    } else if ( lifelist.listViewRankFilter === "default" ) {
      nodeShouldDisplay = node => node.parent_id === ( openTaxon ? openTaxon.id : 0 );
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
    if ( lifelist.treeSort === "name" ) {
      sortMethod = t => t.name;
    } else if ( lifelist.treeSort === "taxonomic" ) {
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
        <div className="more" key={`more-${lifelist.listViewScrollPage}-${openTaxon ? openTaxon.id : null}`}>
          { moreButton }
        </div>
      </div>
    );
  }

  render( ) {
    const { lifelist, openTaxon } = this.props;
    if ( !lifelist.taxa || !lifelist.children ) { return ( <span /> ); }
    return (
      <div id="TaxaList" key={`tree-${lifelist.treeSort}-${lifelist.listViewRankFilter}`}>
        <ul className="list">
          { this.showNode( openTaxon ) }
        </ul>
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
  setListViewOpenTaxon: PropTypes.func
};

export default TaxaList;
