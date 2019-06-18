import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import SplitTaxon from "../../../shared/components/split_taxon";
import util from "../../show/util";

class TaxaTree extends React.Component {
  constructor( ) {
    super( );
    this.showNodeList = this.showNodeList.bind( this );
  }

  roots( ) {
    const { taxa, children } = this.props;
    return _.sortBy( _.map( children[0], taxonID => taxa[taxonID] ), "name" );
  }

  showNodeList( taxon ) {
    const {
      taxa, children, toggleTaxon, openTaxa, setDetailsTaxon, showPhotos
    } = this.props;
    // const isLeaf = !children[taxon.id];
    // const isOpen = _.includes( openTaxa, taxon.id );
    const isLeaf = !children[taxon.id];
    const isOpen = _.includes( openTaxa, taxon.id );
    const childrenTaxa = isLeaf ? [] : _.map( children[taxon.id], childID => taxa[childID] );
    return (
      <li key={`branch-${taxon.id}`}>
        <div className="name-row">
          <div
            className="name-label"
            onClick={( ) => toggleTaxon( taxon )}
          >
            { showPhotos ? util.taxonImage( taxon ) : null }
            <SplitTaxon taxon={taxon} noInactive sciFirst />
          </div>
          { ( taxon.descendantCount <= 200 && !isLeaf ) ? (
            <span>
              &nbsp;&nbsp;
              <span
                className="expand"
                role="button"
                tabIndex={0}
                onClick={( ) => toggleTaxon( taxon, { expand: true } )}
              >
                +
              </span>
            </span>
          ) : null }
          &nbsp;&nbsp;
          { isLeaf ? null : (
            <span
              className="expand"
              role="button"
              tabIndex={0}
              onClick={( ) => toggleTaxon( taxon, { collapse: true } )}
            >
              -
            </span>
          ) }
          &nbsp;&nbsp;
          <span
            className="expand"
            role="button"
            tabIndex={0}
            onClick={( ) => toggleTaxon( taxon, { feature: true } )}
          >
            =
          </span>
          &nbsp;&nbsp;
          <span className="obscount">
            { taxon.descendantCount }
          </span>
          &nbsp;&nbsp;
          <span
            className="fa fa-info-circle"
            onClick={( ) => setDetailsTaxon( taxon )}
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
    const { taxa, children } = this.props;
    if ( !taxa || !children ) { return ( <span /> ); }
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
  taxa: PropTypes.object,
  children: PropTypes.object,
  openTaxa: PropTypes.array,
  setDetailsTaxon: PropTypes.func,
  toggleTaxon: PropTypes.func,
  showPhotos: PropTypes.bool
};

export default TaxaTree;
