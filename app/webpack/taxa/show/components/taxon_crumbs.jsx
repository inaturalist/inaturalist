import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import SplitTaxon from "../../../observations/identify/components/split_taxon";

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
    const urlForTaxon = ( t ) => `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}?test=taxon-page`;
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
      if ( this.state.ancestorsShown ) {
        contractControl = (
          <a className="contract-control" href="#" onClick={ ( ) => this.hideAncestors( ) }>
            <i className="glyphicon glyphicon-circle-arrow-left" />
          </a>
        );
      } else {
        expandControl = (
          <li><a href="#" onClick={ ( ) => this.showAncestors( ) }>...</a></li>
        );
      }
    }
    return (
      <ul className="TaxonCrumbs inline">
        <li>
          <SplitTaxon taxon={ancestors[0]} />
        </li>
        { firstVisibleAncestor }
        { expandControl }
        { ancestorTaxa.map( t => (
          <li
            key={`taxon-crumbs-${t.id}`}
            className={ this.state.ancestorsShown ? "" : "hidden" }
          >
            <SplitTaxon taxon={t} url={urlForTaxon( t )} />
          </li>
        ) ) }
        { lastVisibleAncestor }
        <li>
          <SplitTaxon taxon={taxon} />
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
