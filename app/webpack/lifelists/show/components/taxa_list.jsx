/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */
import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Badge } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import AncestryBreadcrumbs from "../containers/ancestry_breadcrumbs_container";

class TaxaList extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.showNode = this.showNode.bind( this );
  }

  showNode( taxon, isChild, nodeDisplayedCount ) {
    const {
      lifelist, detailsTaxon, setDetailsTaxon,
      config, setDetailsView
    } = this.props;
    nodeDisplayedCount += 1;
    const parentNodeDisplayedCount = nodeDisplayedCount;
    const breadcrumbs = isChild || !lifelist.listShowAncestry ? null : (
      <AncestryBreadcrumbs
        taxon={taxon}
        keyPrefix={parentNodeDisplayedCount}
      />
    );
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
    const leaves = [];
    if ( !isChild ) {
      const { count, element } = this.showTaxaList( taxon, nodeDisplayedCount );
      nodeDisplayedCount = count;
      leaves.push( element );
    }
    return {
      count: nodeDisplayedCount,
      element: (
        <li
          className={`${isChild ? "child" : ""}`}
          key={`branch-${taxon ? taxon.id : 0}`}
        >
          { breadcrumbs }
          <div className="name-row">
            <div
              className={nameClasses.join( " " )}
              onClick={( ) => {
                setDetailsTaxon( taxon );
              }}
            >
              { taxon ? (
                <SplitTaxon
                  taxon={taxon}
                  key={`${taxon.id}-${parentNodeDisplayedCount}`}
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
                if ( lifelist.detailsView !== "observations" ) {
                  setDetailsView( "species" );
                }
              }}
              title={`${lifelist.detailsView === "observations" ? "View observations" : "View speciews"}`}
            />
          </div>
          { leaves }
        </li>
      )
    };
  }

  showTaxaList( taxon = null, nodeDisplayedCount = 0 ) {
    const { lifelist, searchTaxon } = this.props;
    let taxaToList = [];
    if ( taxon ) {
      const children = _.map( lifelist.milestoneChildren[taxon.id], id => lifelist.taxa[id] );
      taxaToList = _.filter( children, t => t.right === t.left + 1 );
      if ( searchTaxon ) {
        taxaToList = _.filter( taxaToList,
          t => t.left >= searchTaxon.left && t.right <= searchTaxon.right );
      }
    } else {
      taxaToList = _.map( lifelist.simplifiedLeafParents, id => lifelist.taxa[id] );
      if ( searchTaxon ) {
        taxaToList = _.filter( taxaToList,
          t => (
            ( t.left >= searchTaxon.left && t.right <= searchTaxon.right )
            || ( t.id === searchTaxon.milestoneParentID && !lifelist.milestoneChildren[searchTaxon.id] )
          ) );
      }
    }
    let sortMethod;
    if ( lifelist.treeSort === "name" ) {
      sortMethod = t => t.preferred_common_name || t.name;
    } else if ( lifelist.treeSort === "taxonomic" ) {
      sortMethod = taxon ? "left" : "right";
    } else {
      sortMethod = taxon
        ? ( t => -1 * t.descendant_obs_count )
        : ["rank_level", t => -1 * t.descendant_obs_count];
    }
    const sortedTaxaToList = _.sortBy( taxaToList, sortMethod );

    const nodes = [];
    const countLimit = lifelist.listViewScrollPage * lifelist.listViewPerPage;
    _.each( sortedTaxaToList, t => {
      if ( nodeDisplayedCount >= countLimit
        || ( !taxon && nodeDisplayedCount + 1 >= countLimit ) ) {
        nodeDisplayedCount = countLimit;
        return;
      }
      const { count, element } = this.showNode( t, !!taxon, nodeDisplayedCount );
      nodeDisplayedCount = count;
      nodes.push( element );
    } );

    return {
      count: nodeDisplayedCount,
      element: (
        <ul
          key={`list-${taxon ? taxon.id : 0}`}
          className={taxon ? "nested" : "tree"}
        >
          { nodes }
        </ul>
      )
    };
  }

  render( ) {
    const { lifelist, setListViewScrollPage, searchTaxon } = this.props;
    if ( !lifelist.taxa || !lifelist.children ) { return ( <span /> ); }
    const { count, element } = this.showTaxaList( );
    let moreButton;
    if ( count >= lifelist.listViewScrollPage * lifelist.listViewPerPage ) {
      moreButton = (
        <div className="more" key={`more-${lifelist.listViewScrollPage}`}>
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
        </div>
      );
    }

    return (
      <div id="TaxaList" key={`tree-${lifelist.treeSort}-${searchTaxon && searchTaxon.id}`}>
        { element }
        { moreButton }
      </div>
    );
  }
}

TaxaList.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  detailsTaxon: PropTypes.object,
  searchTaxon: PropTypes.object,
  setDetailsTaxon: PropTypes.func,
  setDetailsView: PropTypes.func,
  setListViewScrollPage: PropTypes.func
};

export default TaxaList;
