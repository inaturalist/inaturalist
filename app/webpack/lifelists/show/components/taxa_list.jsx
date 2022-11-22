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
    // the details taxon, or its parent if its a subspecies, will be `featured`
    if ( detailsTaxon && taxon && (
      detailsTaxon.id === taxon.id || (
        detailsTaxon.rank_level < 10 && detailsTaxon.parent_id === taxon.id
      )
    ) ) {
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
                  { I18n.t( "all_taxa.life" ) }
                </div>
              ) }
            </div>
            { ( !( isLeaf && taxon && taxon.rank_level > 10 ) && descendantObsCount ) ? (
              <span
                className="descendants"
                onClick={( ) => setDetailsTaxon( taxon )}
                title={I18n.t( "views.lifelists.all_observations_in_this_taxon" )}
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
                title={I18n.t( "views.lifelists.observations_of_exactly_this_taxon" )}
              >
                { directObsCount }
              </Badge>
            ) : null }
          </div>
          { leaves }
        </li>
      )
    };
  }

  showTaxaList( taxon = null, nodeDisplayedCount = 0 ) {
    const { config, lifelist, searchTaxon } = this.props;
    let taxaToList = [];
    // if the search taxon is a subspecies, use its parent as the search taxon
    // since subspecies aren't shown in the list view
    let searchTaxonListLeaf = searchTaxon;
    if ( searchTaxon && searchTaxon.rank_level < 10 ) {
      searchTaxonListLeaf = lifelist.taxa[searchTaxon.parent_id];
    }
    if ( taxon ) {
      const children = _.map( lifelist.milestoneChildren[taxon.id], id => lifelist.taxa[id] );
      // listing milestone leaf children of the taxon,
      // or non-leaf species (sp with ssp) since ssp aren't shown in list view
      taxaToList = _.filter( children, t => (
        ( t.right === t.left + 1 && t.rank_level >= 10 )
        || t.rank_level === 10 ) );
      if ( searchTaxonListLeaf ) {
        taxaToList = _.filter( taxaToList,
          t => t.left >= searchTaxonListLeaf.left && t.right <= searchTaxonListLeaf.right );
      }
    } else {
      taxaToList = _.map( lifelist.simplifiedLeafParents, id => lifelist.taxa[id] );
      taxaToList = _.filter( taxaToList, t => t.rank_level > 10 );
      if ( searchTaxonListLeaf ) {
        taxaToList = _.filter( taxaToList,
          t => (
            ( t.left >= searchTaxonListLeaf.left && t.right <= searchTaxonListLeaf.right )
            || ( t.id === searchTaxonListLeaf.milestoneParentID )
          ) );
      }
    }
    let sortMethod;
    if ( lifelist.treeSort === "name" ) {
      sortMethod = t => ( config.currentUser && config.currentUser.prefers_scientific_name_first
        ? t.name
        : t.preferred_common_name || t.name
      );
    } else if ( lifelist.treeSort === "taxonomic" ) {
      sortMethod = taxon ? "left" : "right";
    } else if ( lifelist.treeSort === "obsAsc" ) {
      sortMethod = taxon
        ? ( t => t.descendant_obs_count )
        : ["rank_level", t => t.descendant_obs_count];
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
            { I18n.t( "show_more" ) }
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
