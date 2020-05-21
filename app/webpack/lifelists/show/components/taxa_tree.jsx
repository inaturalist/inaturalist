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
    this.state = {
      clickedTaxonID: null,
      doubleClickedTaxonID: null
    };
  }

  roots( ) {
    const { lifelist } = this.props;
    return _.sortBy( _.map( lifelist.children[0], taxonID => lifelist.taxa[taxonID] ), "name" );
  }

  showNodeList( taxon ) {
    const {
      lifelist, toggleTaxon, setDetailsTaxon, config, setDetailsView
    } = this.props;
    const isLeaf = !lifelist.children[taxon.id];
    const isOpen = _.includes( lifelist.openTaxa, taxon.id );
    const childrenTaxa = isLeaf ? [] : _.map( lifelist.children[taxon.id], childID => lifelist.taxa[childID] );
    const nameClasses = ["name-label"];
    if ( lifelist.detailsTaxon && lifelist.detailsTaxon.id === taxon.id ) {
      nameClasses.push( "featured" );
    }
    if ( lifelist.detailsTaxon && taxon.left < lifelist.detailsTaxon.left && taxon.right > lifelist.detailsTaxon.right ) {
      nameClasses.push( "featured-ancestor" );
    }
    return (
      <li className="branch" taxon-id={`branch-${taxon.id}`} key={`branch-${taxon.id}`}>
        <div className="name-row">
          <div
            className={nameClasses.join( " " )}
            onClick={e => {
              const clickedTaxonID = $( $( e.nativeEvent.target ).parents( "li.branch" )[0] )
                .attr( "taxon-id" );
              if ( this.state.clickedTaxonID && this.state.clickedTaxonID === clickedTaxonID ) {
                setDetailsTaxon( taxon );
                this.state.clickedTaxonID = null;
                this.state.doubleClickedTaxonID = clickedTaxonID;
                return;
              }
              this.state.clickedTaxonID = clickedTaxonID;
              setTimeout( ( ) => {
                if ( this.state.doubleClickedTaxonID && this.state.doubleClickedTaxonID === clickedTaxonID ) {
                  this.state.doubleClickedTaxonID = null;
                  return;
                }
                toggleTaxon( taxon );
                this.state.clickedTaxonID = null;
              }, 150 );
              e.preventDefault();
            }}
          >
            <SplitTaxon
              taxon={taxon}
              key={`${taxon.name}-${taxon.preferred_common_name}`}
              user={config.currentUser}
            />
          </div>
          { isLeaf ? null : (
            <span
              className={`fa fa-chevron-up ${isOpen ? "" : "disabled"}`}
              onClick={( ) => toggleTaxon( taxon, { collapse: true } )}
              title="Expand all nodes in this branch"
            />
          ) }
          { ( taxon.descendantCount <= 200 && !isLeaf ) ? (
            <span
              className="fa fa-chevron-down"
              onClick={( ) => toggleTaxon( taxon, { expand: true } )}
              title="Collapse this branch"
            />
          ) : null }
          <span
            className="fa fa-square-o"
            onClick={( ) => toggleTaxon( taxon, { feature: true } )}
            title="Focus tree on this taxon"
          />
          { ( !isLeaf && taxon.descendant_obs_count ) ? (
            <span
              className="descendants"
              onClick={( ) => {
                setDetailsTaxon( taxon );
                setDetailsView( "observations" );
              }}
              title="All observations in this taxon"
            >
              { taxon.descendant_obs_count }
            </span>
          ) : null }
          { taxon.direct_obs_count ? (
            <Badge
              className="green"
              onClick={( ) => {
                setDetailsTaxon( taxon, { without_descendants: true } );
                setDetailsView( "observations" );
              }}
              title="Observations of exactly this taxon"
            >
              { taxon.direct_obs_count }
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
          <ul>
            { _.map( _.sortBy( childrenTaxa, "name" ), this.showNodeList ) }
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
          { _.map( this.roots( ), this.showNodeList ) }
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
