import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

class TaxonCrumbs extends React.Component {

  hideChildren( ) {
    $( "body" ).click( );
  }

  clickedTaxonLink( e, taxon ) {
    if ( !this.props.showNewTaxon ) {
      return true;
    }
    if ( e.metaKey || e.ctrlKey ) return true;
    e.preventDefault( );
    this.hideChildren( );
    this.props.showNewTaxon( taxon );
    return false;
  }

  render( ) {
    const { taxon, ancestors, showAncestors, hideAncestors, config } = this.props;
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
          <SplitTaxon
            taxon={fva}
            url={urlForTaxon( fva )}
            onClick={ e => this.clickedTaxonLink( e, fva ) }
            user={ config.currentUser }
          />
        </li>
      );
      if ( ancestorTaxa.length > 0 ) {
        const lva = ancestorTaxa.pop( );
        lastVisibleAncestor = (
          <li>
            <SplitTaxon
              taxon={lva}
              url={urlForTaxon( lva )}
              onClick={ e => this.clickedTaxonLink( e, lva ) }
              user={ config.currentUser }
            />
          </li>
        );
      }
    }
    if ( ancestorTaxa.length > 0 ) {
      if ( this.props.ancestorsShown ) {
        contractControl = (
          <a
            className="contract-control"
            href="#"
            onClick={ e => {
              e.preventDefault( );
              hideAncestors( );
              return false;
            } }
          >
            <i className="glyphicon glyphicon-circle-arrow-left" />
          </a>
        );
      } else {
        expandControl = (
          <li className="expand-control">
            <a
              href="#"
              onClick={ e => {
                e.preventDefault( );
                showAncestors( );
                return false;
              } }
            >...</a>
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
                    <SplitTaxon
                      taxon={t}
                      url={urlForTaxon( t )}
                      forceRank
                      onClick={ e => this.clickedTaxonLink( e, t ) }
                      user={ config.currentUser }
                    />
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
          <SplitTaxon taxon={targetTaxon} user={ config.currentUser } />
          { descendants }
        </span>
      );
    };
    return (
      <ul className={`TaxonCrumbs inline ${this.props.ancestorsShown ? "expanded" : "contracted"}`}>
        <li>
          <SplitTaxon taxon={{ name: I18n.t( "life" ), is_active: true }} user={ config.currentUser } />
        </li>
        { firstVisibleAncestor }
        { expandControl }
        { ancestorTaxa.map( t => (
          <li key={`taxon-crumbs-${t.id}`} className="inner">
            <SplitTaxon
              taxon={t}
              url={urlForTaxon( t )}
              onClick={ e => this.clickedTaxonLink( e, t ) }
              user={ config.currentUser }

            />
          </li>
        ) ) }
        { lastVisibleAncestor }
        { this.props.currentText ? (
          <li>
            <SplitTaxon
              taxon={taxon}
              url={urlForTaxon( taxon )}
              onClick={ e => this.clickedTaxonLink( e, taxon ) }
              user={ config.currentUser }
            />
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
  hideAncestors: PropTypes.func,
  showNewTaxon: PropTypes.func,
  config: PropTypes.object
};

TaxonCrumbs.defaultProps = {
  ancestors: [],
  config: {}
};

export default TaxonCrumbs;
