import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import { urlForTaxon } from "../util";
import SplitTaxon from "../../../observations/identify/components/split_taxon";

const TaxonomyTab = ( { taxon, taxonChangesCount, taxonSchemesCount } ) => {
  const currentTaxon = Object.assign( { }, taxon );
  const tree = [];
  if ( taxon && taxon.ancestors ) {
    const ancestors = Object.assign( [], currentTaxon.ancestors );
    ancestors.push( currentTaxon );
    tree.push( Object.assign( {}, ancestors.shift( ) ) );
    let lastAncestor = tree[0];
    for ( let i = 0; i < ancestors.length; i++ ) {
      lastAncestor.children = lastAncestor.children || [];
      lastAncestor.children.push( Object.assign( {}, ancestors[i] ) );
      lastAncestor = lastAncestor.children[lastAncestor.children.length - 1];
    }
  }
  const renderTaxonomy = taxa => (
    <ul className="plain taxonomy">
      { taxa.map( t => {
        let className = "";
        const isRoot = t.id === tree[0].id;
        if ( t.id === taxon.id ) {
          className += "current";
        }
        if ( isRoot ) {
          className += " root";
        }
        return (
          <li key={`taxonomy-${t.id}`} className={ className }>
            <SplitTaxon taxon={t} url={isRoot ? null : urlForTaxon( t )} /> {
              isRoot ?
                null
                :
                ( <a href={urlForTaxon( t )}><i className="glyphicon glyphicon-new-window"></i></a> )
            }
            { t.children && t.children.length > 0 ? renderTaxonomy( t.children ) : null }
          </li>
        );
      } ) }
    </ul>
  );
  return (
    <Grid className="TaxonomyTab">
      <Row>
        <Col xs={8}>
          { renderTaxonomy( tree ) }
        </Col>
        <Col xs={4}>
          <ul className="tab-links list-group">
            <li className="list-group-item">
              <span className="badge">{ taxonChangesCount }</span>
              <a href={`/taxon_changes?taxon_id=${taxon.id}`}>
                <i className="fa fa-random"></i>
                { I18n.t( "taxon_changes" ) }
              </a>
            </li>
            <li className="list-group-item">
              <a href={`/taxa/${taxon.id}/schemes`}>
                <span className="badge pull-right">{ taxonSchemesCount }</span>
                <i className="glyphicon glyphicon-list-alt"></i>
                { I18n.t( "taxon_schemes" ) }
              </a>
            </li>
          </ul>
        </Col>
      </Row>
    </Grid>
  );
};

TaxonomyTab.propTypes = {
  taxon: PropTypes.object,
  taxonChangesCount: PropTypes.number,
  taxonSchemesCount: PropTypes.number
};

export default TaxonomyTab;
