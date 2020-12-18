/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */
import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Badge } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";

class TaxaTree extends React.Component {
  constructor( ) {
    super( );
    this.showNodeList = this.showNodeList.bind( this );
    this.sortMethod = this.sortMethod.bind( this );
  }

  sortMethod( ) {
    const { config, lifelist } = this.props;
    if ( lifelist.treeSort === "name" ) {
      return t => ( config.currentUser && config.currentUser.prefers_scientific_name_first
        ? t.name
        : t.preferred_common_name || t.name
      );
    }
    if ( lifelist.treeSort === "taxonomic" ) {
      return t => t.left;
    }
    if ( lifelist.treeSort === "obsAsc" ) {
      return t => t.descendant_obs_count;
    }
    return t => -1 * t.descendant_obs_count;
  }

  roots( ) {
    const { lifelist } = this.props;
    return _.sortBy(
      _.map( lifelist.children[0], taxonID => lifelist.taxa[taxonID] ), this.sortMethod( )
    );
  }

  showNodeList( taxon ) {
    const {
      lifelist, toggleTaxon, setDetailsTaxon, config,
      setDetailsView
    } = this.props;
    const simplified = lifelist.treeMode === "simplified";
    const children = ( simplified && !( taxon && taxon.rank_level <= 10 ) )
      ? lifelist.milestoneChildren : lifelist.children;
    const taxonID = taxon ? taxon.id : 0;
    const isLeaf = !children[taxonID];
    const showDirectCount = !taxon || taxon.rank_level > 10;
    const isRoot = !taxon;
    let isOpen = true;
    isOpen = taxon ? _.includes( lifelist.openTaxa, taxon.id ) : true;
    const childrenTaxa = isLeaf ? []
      : _.map( children[taxonID], childID => lifelist.taxa[childID] );
    const descendantObsCount = taxon ? taxon.descendant_obs_count : lifelist.observationsCount;
    const directObsCount = taxon ? taxon.direct_obs_count : lifelist.observationsWithoutTaxon;
    const nameClasses = ["name-label"];
    if ( lifelist.detailsTaxon && lifelist.detailsTaxon.id === taxonID ) {
      nameClasses.push( "featured" );
    }
    if ( !taxon
      || ( lifelist.detailsTaxon
        && taxon.left < lifelist.detailsTaxon.left
        && taxon.right > lifelist.detailsTaxon.right
      ) ) {
      nameClasses.push( "featured-ancestor" );
    }
    const toggleMethod = toggleTaxon;
    return (
      <li className="branch" taxon-id={`branch-${taxonID}`} key={`branch-${taxonID}`}>
        <div className="name-row">
          <div
            className={nameClasses.join( " " )}
            onClick={( ) => toggleMethod( taxon )}
          >
            { taxon ? (
              <SplitTaxon
                taxon={taxon}
                key={`${taxon.name}-${taxon.preferred_common_name}`}
                user={config.currentUser}
              />
            ) : (
              <div className="name-label featured-ancestor display-name">
                { I18n.t( "all_taxa.life" ) }
              </div>
            ) }
          </div>
          { ( isLeaf || isRoot || simplified || !isOpen ) ? null : (
            <span
              className={`icon-collapse ${isOpen ? "" : "disabled"}`}
              onClick={( ) => toggleTaxon( taxon, { collapse: true } )}
              title={I18n.t( "views.lifelists.collapse_this_branch" )}
            />
          ) }
          { ( !isRoot && !isLeaf && !simplified && taxon.descendantCount <= 200 ) ? (
            <span
              className="icon-expand"
              onClick={( ) => toggleTaxon( taxon, { expand: true } )}
              title={I18n.t( "views.lifelists.expand_all_nodes_in_this_branch" )}
            />
          ) : null }
          { ( isRoot || simplified ) ? null : (
            <span
              className="icon-focus"
              onClick={( ) => toggleTaxon( taxon, { feature: true } )}
              title={I18n.t( "views.lifelists.focus_tree_on_this_taxon" )}
            />
          ) }
          { descendantObsCount && !( showDirectCount && isLeaf ) ? (
            <span
              className="descendants"
              onClick={( ) => {
                setDetailsTaxon( taxon, { updateSearch: true } );
                setDetailsView( "observations" );
              }}
              title={I18n.t( "views.lifelists.all_observations_in_this_taxon" )}
            >
              { descendantObsCount }
            </span>
          ) : null }
          { directObsCount && showDirectCount ? (
            <Badge
              className="green"
              onClick={( ) => {
                setDetailsTaxon( taxon, { without_descendants: true, updateSearch: true } );
                setDetailsView( "observations" );
              }}
              title={I18n.t( "views.lifelists.observations_of_exactly_this_taxon" )}
            >
              { directObsCount }
            </Badge>
          ) : null }
          <span
            className={`${lifelist.detailsView === "observations" ? "icon icon-binoculars" : "fa fa-leaf"}`}
            onClick={( ) => {
              setDetailsTaxon( taxon, { updateSearch: true } );
              if ( lifelist.detailsView === "observations" ) {
                setDetailsView( "observations" );
              } else {
                setDetailsView( "species" );
              }
            }}
            title={`${lifelist.detailsView === "observations" ? "View observations" : "View species"}`}
          />
        </div>
        { isOpen && !isLeaf ? (
          <ul className="nested">
            { _.map( _.sortBy( childrenTaxa, this.sortMethod( ) ), this.showNodeList ) }
          </ul>
        ) : null }
      </li>
    );
  }

  render( ) {
    const { lifelist } = this.props;
    if ( !lifelist.taxa || !lifelist.children ) { return ( <span /> ); }
    return (
      <div id="TaxaTree">
        <ul className="tree">
          { this.showNodeList( ) }
        </ul>
      </div>
    );
  }
}

TaxaTree.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  setDetailsTaxon: PropTypes.func,
  setDetailsView: PropTypes.func,
  toggleTaxon: PropTypes.func
};

export default TaxaTree;
