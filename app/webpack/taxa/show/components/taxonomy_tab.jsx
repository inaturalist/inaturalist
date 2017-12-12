import React, { PropTypes } from "react";
import { Grid, Row, Col, OverlayTrigger, Popover } from "react-bootstrap";
import _ from "lodash";
import { urlForTaxon, RANK_LEVELS } from "../../shared/util";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserText from "../../../shared/components/user_text";
import UserWithIcon from "../../../observations/show/components/user_with_icon";

const TaxonomyTab = ( {
  taxon,
  taxonChangesCount,
  taxonSchemesCount,
  names,
  showNewTaxon,
  allChildrenShown,
  toggleAllChildrenShown,
  currentUser
} ) => {
  const currentTaxon = Object.assign( { }, taxon );
  const viewerIsCurator = currentUser && currentUser.roles && (
    currentUser.roles.indexOf( "admin" ) >= 0 || currentUser.roles.indexOf( "curator" ) >= 0
  );
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
      { ( _.sortBy( taxa, t => t.name ) || [] ).map( t => {
        let className = "";
        const isRoot = t.id === tree[0].id;
        const isTaxon = t.id === taxon.id;
        const isDescendant = t.ancestor_ids && t.ancestor_ids.indexOf( taxon.id ) >= 0;
        const shouldLinkToTaxon = !isRoot && !isTaxon;
        const isComplete = isTaxon && taxon.complete_rank && taxon.rank_level > RANK_LEVELS[taxon.complete_rank];
        const isHidable = isDescendant && ( t.rank === "hybrid" || !t.is_active || t.extinct );
        const numChildren = ( t.children || [] ).length;
        const numHidableChildren = _.filter( t.children || [], c => (
          c.rank === "hybrid" || !c.is_active || c.extinct
        ) ).length;
        const tabular = false;
        if ( isTaxon ) {
          className += "current";
        }
        if ( isRoot ) {
          className += " root";
        }
        if ( isComplete ) {
          className += " complete";
        }
        if ( isHidable ) {
          className += " hidable";
        }
        if ( numChildren <= 1 || allChildrenShown ) {
          className += " all-shown";
        }
        if ( tabular ) {
          className += " tabular";
        }
        return (
          <li key={`taxonomy-${t.id}`} className={ className }>
            <div className="row-content">
              <div className="name-row">
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
                { isComplete ? (
                  <div className="inlineblock taxonomy-complete-notice">
                    <div className="label-complete">
                      { I18n.t( `all_rank_added_to_the_database.${taxon.complete_rank || "species"}` ) }
                    </div>
                    <OverlayTrigger
                      trigger="click"
                      rootClose
                      placement="top"
                      animation={false}
                      overlay={
                        <Popover
                          id={ `complete-taxon-popover-${t.id}` }
                          className="complete-taxon-popover"
                          title={ I18n.t( "about_complete_taxa" ) }
                        >
                          { I18n.t( "views.taxa.show.complete_taxon_desc" ) }
                        </Popover>
                      }
                    >
                      <a
                        href={ urlForTaxon( t ) }
                        onClick={ e => {
                          e.preventDefault( );
                          return false;
                        }}
                      >
                        <i className="fa fa-info-circle"></i> { I18n.t( "info" ) }
                      </a>
                    </OverlayTrigger>
                    { numChildren <= 1 || numHidableChildren === 0 ? null : (
                      <span>
                        <span className="text-muted">&bull;</span>
                        <a
                          href="#"
                          onClick={ e => {
                            e.preventDefault( );
                            toggleAllChildrenShown( );
                            return false;
                          }}
                        >
                          { allChildrenShown ? I18n.t( "hide_uncountable_species" ) : I18n.t( "show_uncountable_species" ) }
                        </a>
                      </span>
                    ) }
                  </div>
                ) : null }
              </div>
              { tabular && isTaxon ? (
                <div style={ { whiteSpace: "nowrap" } }>
                  { I18n.t( "observations" ) }
                </div>
              ) : null }
              { tabular && isDescendant ? (
                <div className={`text-${t.observations_count === 0 ? "default" : "success"} label-obs-count`}>
                  { t.observations_count === 0 ? t.observations_count : (
                    <a href={`/observations?taxon_id=${t.id}&place_id=any`}>{ t.observations_count }</a>
                  ) }
                </div>
              ) : null }
            </div>
            { t.children && t.children.length > 0 ? renderTaxonomy( t.children ) : null }
          </li>
        );
      } ) }
    </ul>
  );
  const sortedNames = _.sortBy( names, n => [n.lexicon, n.name] );
  let taxonCurators;
  if ( taxon.taxonCurators && taxon.taxonCurators.length > 0 ) {
    taxonCurators = (
      <div>
        <h4>{ I18n.t( "taxon_curators" ) }</h4>
        <UserText text={ I18n.t( "views.taxa.show.about_taxon_curators_desc" ).replace( /\n+/gm, " " )} truncate={400} />
        { _.map( taxon.taxonCurators, tc => <UserWithIcon user={ tc.user } key={ `taxon-curators-${tc.user.id}` } /> ) }
      </div>
    );
  }
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
              { taxonCurators }
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
                    { currentUser ? (
                      <th>{ I18n.t( "action" ) }</th>
                    ) : null }
                  </tr>
                </thead>
                <tbody>
                  { sortedNames.map( n => (
                    <tr
                      key={`taxon-names-${n.id}`}
                      className={ n.is_valid ? "" : "outdated" }
                    >
                      <td>
                        { I18n.t( `lexicons.${_.snakeCase( n.lexicon )}`, { defaultValue: n.lexicon } ) }
                      </td>
                      <td
                        className={ n.lexicon && _.snakeCase( n.lexicon ).match( /scientific/ ) ? "sciname" : "comname" }
                      >
                        { n.name }
                      </td>
                      { currentUser ? (
                        <td>
                          { viewerIsCurator || n.creator_id === currentUser.id ? (
                            <a href={`/taxon_names/${n.id}/edit`}>{ I18n.t( "edit" ) }</a>
                          ) : null }
                        </td>
                      ) : null }
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
  showNewTaxon: PropTypes.func,
  allChildrenShown: PropTypes.bool,
  toggleAllChildrenShown: PropTypes.func,
  currentUser: PropTypes.object
};

TaxonomyTab.defaultProps = {
  names: [],
  taxonChangesCount: 0,
  taxonSchemesCount: 0,
  allChildrenShown: false
};

export default TaxonomyTab;
