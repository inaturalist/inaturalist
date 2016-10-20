import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import { urlForTaxon } from "../util";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";

const TaxonomyTab = ( { taxon, taxonChangesCount, taxonSchemesCount, names } ) => {
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
  const sortedNames = _.sortBy( names, n => [n.lexicon, n.name] );
  return (
    <Grid className="TaxonomyTab">
      <Row>
        <h2>{ I18n.t( "taxonomy" ) }</h2>
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
      <Row>
        <Col xs={8}>
          <h2>{ I18n.t( "names" ) }</h2>
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
                    { n.lexicon }
                  </td>
                  <td
                    className={ n.lexicon.toLowerCase( ).match( /scientific/ ) ? "sciname" : null }
                  >
                    { n.name }
                  </td>
                  <td><a href={`/taxon_names/${n.id}/edit`}>{ I18n.t( "edit" ) }</a></td>
                </tr>
              ) ) }
            </tbody>
          </table>
          <h2 className={ `text-center ${names.length > 0 ? "hidden" : ""}`}>
            <i className="fa fa-refresh fa-spin"></i>
          </h2>
        </Col>
        <Col xs={4}>
          <ul className="tab-links list-group">
            <li className="list-group-item">
              <a href={`/taxa/${taxon.id}/names`} rel="nofollow">
                <i className="fa fa-gear"></i>
                { I18n.t( "manage_names" ) }
              </a>
            </li>
            <li className="list-group-item">
              <a
                href={`/taxa/${taxon.id}/taxon_names/new`}
                rel="nofollow"
              >
                <i className="fa fa-plus"></i>
                { I18n.t( "add_a_name" ) }
              </a>
            </li>
          </ul>

          <h3>{ I18n.t( "about_names" ) }</h3>
          <UserText text={I18n.t( "views.taxa.show.about_names_desc" )} truncate={400} />
        </Col>
      </Row>
    </Grid>
  );
};

TaxonomyTab.propTypes = {
  taxon: PropTypes.object,
  taxonChangesCount: PropTypes.number,
  taxonSchemesCount: PropTypes.number,
  names: PropTypes.array
};

TaxonomyTab.defaultProps = {
  names: []
};

export default TaxonomyTab;
