import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

class TaxonCrumbs extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      childrenSHown: false
    };
  }

  showChildren( ) {
    this.setState( { childrenShown: true } );
  }

  hideChildren( ) {
    this.setState( { childrenShown: false } );
  }

  render( ) {
    const { taxon, ancestors, showAncestors, hideAncestors } = this.props;
    const children = _.sortBy( taxon.children || [], t => t.name );
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
      if ( this.props.ancestorsShown ) {
        contractControl = (
          <a className="contract-control" href="#" onClick={ ( ) => hideAncestors( ) }>
            <i className="glyphicon glyphicon-circle-arrow-left" />
          </a>
        );
      } else {
        expandControl = (
          <li className="expand-control">
            <a href="#" onClick={ ( ) => showAncestors( ) }>...</a>
          </li>
        );
      }
    }
    const crumbTaxon = targetTaxon => {
      let descendants;
      if ( children.length > 0 ) {
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
      <ul className={`TaxonCrumbs inline ${this.props.ancestorsShown ? "expanded" : "contracted"}`}>
        <li>
          <SplitTaxon taxon={{ name: "Life", is_active: true }} />
        </li>
        { firstVisibleAncestor }
        { expandControl }
        { ancestorTaxa.map( t => (
          <li key={`taxon-crumbs-${t.id}`} className="inner">
            <SplitTaxon taxon={t} url={urlForTaxon( t )} />
          </li>
        ) ) }
        { lastVisibleAncestor }
        { this.props.currentText ? (
          <li>
            <SplitTaxon taxon={taxon} url={urlForTaxon( taxon )} />
          </li>
        ) : null }
        { this.props.currentText ? (
          <li>
            { this.props.currentText }
            { contractControl }
          </li>
        ) : (
          <li>
            { crumbTaxon( taxon ) }
            { contractControl }
          </li>
        )}
      </ul>
    );
  }
}

TaxonCrumbs.propTypes = {
  taxon: PropTypes.object,
  ancestors: PropTypes.array,
  currentText: PropTypes.string,
  ancestorsShown: PropTypes.bool,
  showAncestors: PropTypes.func,
  hideAncestors: PropTypes.func
};

TaxonCrumbs.defaultProps = { ancestors: [] };

export default TaxonCrumbs;
