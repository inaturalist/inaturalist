import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

class TaxonCrumbs extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      ancestorsShown: false,
      childrenSHown: false
    };
  }

  showAncestors( ) {
    this.setState( { ancestorsShown: true, childrenShown: false } );
  }

  hideAncestors( ) {
    this.setState( { ancestorsShown: false, childrenShown: false } );
  }

  showChildren( ) {
    this.setState( { childrenShown: true } );
  }

  hideChildren( ) {
    this.setState( { childrenShown: false } );
  }

  render( ) {
    const taxon = this.props.taxon;
    const ancestors = this.props.ancestors;
    const children = taxon.children || [];
    const ancestorTaxa = _.filter( ancestors, t => t.name !== "Life" && t.id !== taxon.id );
    let expandControl;
    let contractControl;
    let firstVisibleAncestor;
    let lastVisibleAncestor;
    if ( ancestorTaxa.length > 0 ) {
      const fva = ancestorTaxa.shift( );
      firstVisibleAncestor = (
        <li>
          <SplitTaxon taxon={fva} url={urlForTaxon( fva )} />
        </li>
      );
      if ( ancestorTaxa.length > 0 ) {
        const lva = ancestorTaxa.pop( );
        lastVisibleAncestor = (
          <li>
            <SplitTaxon taxon={lva} url={urlForTaxon( lva )} />
          </li>
        );
      }
    }
    if ( ancestorTaxa.length > 0 ) {
      contractControl = (
        <a className="contract-control" href="#" onClick={ ( ) => this.hideAncestors( ) }>
          <i className="glyphicon glyphicon-circle-arrow-left" />
        </a>
      );
      expandControl = (
        <li className="expand-control">
          <a href="#" onClick={ ( ) => this.showAncestors( ) }>...</a>
        </li>
      );
    }
    const crumbTaxon = targetTaxon => {
      let descendants;
      if ( taxon.children && taxon.children.length > 0 ) {
        descendants = (
          <OverlayTrigger
            trigger="click"
            placement="bottom"
            rootClose
            overlay={
              <Popover
                id={`taxon-crumbs-children-${targetTaxon.id}`}
                className="taxon-crumbs-children"
              >
                { children.map( t => (
                  <div className="child" key={`taxon-crumbs-children-${t.id}`}>
                    <SplitTaxon taxon={t} url={urlForTaxon( t )} forceRank />
                  </div>
                ) ) }
              </Popover>
            }
          >
            <Button bsSize="xs" bsStyle="link">
              <i className="fa fa-caret-down" />
            </Button>
          </OverlayTrigger>
        );
      }
      return (
        <span>
          <SplitTaxon taxon={targetTaxon} />
          { descendants }
        </span>
      );
    };
    return (
      <ul className={`TaxonCrumbs inline ${this.state.ancestorsShown ? "expanded" : "contracted"}`}>
        <li>
          <SplitTaxon taxon={{ name: "Life", is_active: true }} />
        </li>
        { firstVisibleAncestor }
        { expandControl }
        <li className="inner">
          <ul className="inline">
            { ancestorTaxa.map( t => (
              <li key={`taxon-crumbs-${t.id}`}>
                <SplitTaxon taxon={t} url={urlForTaxon( t )} />
              </li>
            ) ) }
          </ul>
        </li>
        { lastVisibleAncestor }
        <li>
          { crumbTaxon( taxon ) }
          { contractControl }
        </li>
      </ul>
    );
  }
}

TaxonCrumbs.propTypes = {
  taxon: PropTypes.object,
  ancestors: PropTypes.array
};

TaxonCrumbs.defaultProps = { ancestors: [] };

export default TaxonCrumbs;
