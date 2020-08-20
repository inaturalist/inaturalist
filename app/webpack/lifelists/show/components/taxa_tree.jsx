/* eslint jsx-a11y/click-events-have-key-events: 0 */
/* eslint jsx-a11y/no-static-element-interactions: 0 */
/* eslint react/destructuring-assignment: 0 */
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
    const { lifelist } = this.props;
    if ( lifelist.treeSort === "name" ) {
      return t => t.name;
    }
    if ( lifelist.treeSort === "taxonomic" ) {
      return t => t.left;
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
      setDetailsView, mode, setListViewOpenTaxon
    } = this.props;
    if ( lifelist.treeMode === "list"
      && !lifelist.treeIndent
      && taxon
      && lifelist.listViewOpenTaxon
      && !_.inRange( lifelist.listViewOpenTaxon.left, taxon.left, taxon.right )
      && !_.inRange( taxon.left, lifelist.listViewOpenTaxon.left, lifelist.listViewOpenTaxon.right )
      && taxon.id !== lifelist.listViewOpenTaxon.id ) {
      return null;
    }
    const children = ( mode === "simplified" ) ? lifelist.milestoneChildren : lifelist.children;
    const taxonID = taxon ? taxon.id : 0;
    const isLeaf = !children[taxonID];
    const isRoot = !taxon;
    let isOpen = true;
    if ( lifelist.treeMode === "list" ) {
      if ( !lifelist.listViewOpenTaxon && taxon ) {
        isOpen = false;
      }
      if ( lifelist.listViewOpenTaxon
        && taxon
        && taxon.id !== lifelist.listViewOpenTaxon.id
        && !_.includes( lifelist.listViewOpenTaxon.ancestors, taxon.id )
      ) {
        isOpen = false;
      }
    } else {
      isOpen = taxon ? _.includes( lifelist.openTaxa, taxon.id ) : true;
    }
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
    let childrenListClass = "nested";
    if ( lifelist.treeMode === "list"
      && !lifelist.treeIndent
      && lifelist.listViewOpenTaxon
      && !( taxon && (
        taxon.id === lifelist.listViewOpenTaxon.id
        || ( mode === "simplified"
          && taxon.id === lifelist.listViewOpenTaxon.nearestMilestoneTaxonID ) ) ) ) {
      childrenListClass = null;
    }
    const listMode = lifelist.treeMode === "list";
    const toggleMethod = lifelist.treeMode === "list" ? setListViewOpenTaxon : toggleTaxon;
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
              <div className="name-label featured-ancestor">
                Life
              </div>
            ) }
          </div>
          { ( isLeaf || isRoot || listMode ) ? null : (
            <span
              className={`icon-collapse ${isOpen ? "" : "disabled"}`}
              onClick={( ) => toggleTaxon( taxon, { collapse: true } )}
              title="Expand all nodes in this branch"
            />
          ) }
          { ( !isRoot && !isLeaf && !listMode && taxon.descendantCount <= 200 ) ? (
            <span
              className="icon-expand"
              onClick={( ) => toggleTaxon( taxon, { expand: true } )}
              title="Collapse this branch"
            />
          ) : null }
          { isRoot || listMode ? null : (
            <span
              className="icon-focus"
              onClick={( ) => toggleTaxon( taxon, { feature: true } )}
              title="Focus tree on this taxon"
            />
          ) }
          { ( !isLeaf && descendantObsCount ) ? (
            <span
              className="descendants"
              onClick={( ) => {
                setDetailsTaxon( taxon );
                setDetailsView( "observations" );
              }}
              title="All observations in this taxon"
            >
              { descendantObsCount }
            </span>
          ) : null }
          { directObsCount ? (
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
        { isOpen && !isLeaf ? (
          <ul className={childrenListClass}>
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
  mode: PropTypes.string,
  setDetailsTaxon: PropTypes.func,
  setDetailsView: PropTypes.func,
  toggleTaxon: PropTypes.func,
  setListViewOpenTaxon: PropTypes.func
};

export default TaxaTree;
