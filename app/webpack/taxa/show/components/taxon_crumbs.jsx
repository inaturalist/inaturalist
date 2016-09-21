import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";
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
    this.setState( { ancestorsShown: true } );
  }

  hideAncestors( ) {
    this.setState( { ancestorsShown: false } );
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
        <li className="expand-control"><a href="#" onClick={ ( ) => this.showAncestors( ) }>...</a></li>
      );
    }
    let descendants;
    if ( children && children.length > 0 ) {
      descendants = (
        <OverlayTrigger
          trigger="click"
          placement="bottom"
          overlay={
            <Popover id="taxon-crumbs-children">
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
      <ul className={`TaxonCrumbs inline ${this.state.ancestorsShown ? "expanded" : "contracted"}`}>
        <li>
          <SplitTaxon taxon={ancestors[0]} />
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
          <SplitTaxon taxon={taxon} />
          { descendants }
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
