import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import { urlForTaxon } from "../../shared/util";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";

const TaxonomyTab = ( {
  taxon,
  taxonChangesCount,
  taxonSchemesCount,
  names,
  showNewTaxon
} ) => {
  const currentTaxon = Object.assign( { }, taxon );
  const tree = [];
  if ( taxon ) {
    if ( taxon.ancestors ) {
      const ancestors = Object.assign( [], currentTaxon.ancestors );
      ancestors.push( currentTaxon );
      tree.push( Object.assign( {}, ancestors.shift( ) ) );
      let lastAncestor = tree[0];
      for ( let i = 0; i < ancestors.length; i++ ) {
        lastAncestor.children = lastAncestor.children || [];
        lastAncestor.children.push( Object.assign( {}, ancestors[i] ) );
        lastAncestor = lastAncestor.children[lastAncestor.children.length - 1];
      }
    } else {
      tree.push( taxon );
    }
  }
  const renderTaxonomy = taxa => (
    <ul className="plain taxonomy">
      { _.sortBy( taxa, t => t.name ).map( t => {
        let className = "";
        const isRoot = t.id === tree[0].id;
        const isTaxon = t.id === taxon.id;
        const shouldLinkToTaxon = !isRoot && !isTaxon;
        if ( isTaxon ) {
          className += "current";
        }
        if ( isRoot ) {
          className += " root";
        }
        return (
          <li key={`taxonomy-${t.id}`} className={ className }>
            <SplitTaxon
              taxon={t}
              url={shouldLinkToTaxon ? urlForTaxon( t ) : null}
              forceRank
              onClick={ e => {
                if ( !shouldLinkToTaxon ) return true;
                if ( e.metaKey || e.ctrlKey ) return true;
                e.preventDefault( );
                showNewTaxon( t, { skipScrollTop: true } );
                return false;
              } }
            />
            { t.children && t.children.length > 0 ? renderTaxonomy( t.children ) : null }
          </li>
        );
      } ) }
    </ul>
  );
  const sortedNames = _.sortBy( names, n => [n.lexicon, n.name] );
  return (
    <Grid className="TaxonomyTab">
      <Row className="tab-section">
        <Col xs={12}>
          <Row>
            <Col xs={8}>
              <h3>{ I18n.t( "taxonomy" ) }</h3>
              { renderTaxonomy( tree ) }
            </Col>
            <Col xs={4}>
              <ul className="tab-links list-group">
                <li className="list-group-item internal">
                  <a href={`/taxon_changes?taxon_id=${taxon.id}`}>
                    <span className="badge pull-right">
                      { I18n.toNumber( taxonChangesCount, { precision: 0 } ) }
                    </span>
                    <i className="fa fa-random accessory-icon"></i>
                    { I18n.t( "taxon_changes" ) }
                  </a>
                </li>
                <li className="list-group-item internal">
                  <a href={`/taxa/${taxon.id}/schemes`}>
                    <span className="badge pull-right">
                      { I18n.toNumber( taxonSchemesCount, { precision: 0 } ) }
                    </span>
                    <i className="glyphicon glyphicon-list-alt accessory-icon"></i>
                    { I18n.t( "taxon_schemes" ) }
                  </a>
                </li>
              </ul>
            </Col>
          </Row>
        </Col>
      </Row>
      <Row className="tab-section">
        <Col xs={12}>
          <Row>
            <Col xs={8}>
              <h3>{ I18n.t( "names" ) }</h3>
              <table className="table table-striped">
                <thead>
                  <tr>
                    <th>{ I18n.t( "language_slash_type" ) }</th>
                    <th>{ I18n.t( "name" ) }</th>
                    <th>{ I18n.t( "action" ) }</th>
                  </tr>
                </thead>
                <tbody>
                  { sortedNames.map( n => (
                    <tr
                      key={`taxon-names-${n.id}`}
                      className={!n.is_valid && n.lexicon === "Scientific Names" ? "outdated" : ""}
                    >
                      <td>
                        { I18n.t( `lexicons.${_.snakeCase( n.lexicon )}`, { defaultValue: n.lexicon } ) }
                      </td>
                      <td
                        className={ n.lexicon && _.snakeCase( n.lexicon ).match( /scientific/ ) ? "sciname" : null }
                      >
                        { n.name }
                      </td>
                      <td><a href={`/taxon_names/${n.id}/edit`}>{ I18n.t( "edit" ) }</a></td>
                    </tr>
                  ) ) }
                </tbody>
              </table>
              <h3 className={ `text-center ${names.length > 0 ? "hidden" : ""}`}>
                <i className="fa fa-refresh fa-spin"></i>
              </h3>
            </Col>
            <Col xs={4}>
              <ul className="tab-links list-group">
                <li className="list-group-item internal">
                  <a href={`/taxa/${taxon.id}/names`} rel="nofollow">
                    <i className="fa fa-gear accessory-icon"></i>
                    { I18n.t( "manage_names" ) }
                  </a>
                </li>
                <li className="list-group-item internal">
                  <a
                    href={`/taxa/${taxon.id}/taxon_names/new`}
                    rel="nofollow"
                  >
                    <i className="fa fa-plus accessory-icon"></i>
                    { I18n.t( "add_a_name" ) }
                  </a>
                </li>
              </ul>
              <h4>{ I18n.t( "about_names" ) }</h4>
              <UserText text={ I18n.t( "views.taxa.show.about_names_desc" ).replace( /\n+/gm, " " )} truncate={400} />
            </Col>
          </Row>
        </Col>
      </Row>
    </Grid>
  );
};

TaxonomyTab.propTypes = {
  taxon: PropTypes.object,
  taxonChangesCount: PropTypes.number,
  taxonSchemesCount: PropTypes.number,
  names: PropTypes.array,
  showNewTaxon: PropTypes.func
};

TaxonomyTab.defaultProps = {
  names: [],
  taxonChangesCount: 0,
  taxonSchemesCount: 0
};

export default TaxonomyTab;
