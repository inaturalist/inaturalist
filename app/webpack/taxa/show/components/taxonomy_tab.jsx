import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Grid,
  Row,
  Col
} from "react-bootstrap";
import UserText from "../../../shared/components/user_text";
import TaxonomicBranch from "../../../shared/components/taxonomic_branch";

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
  const viewerIsCurator = currentUser && currentUser.roles && (
    currentUser.roles.indexOf( "admin" ) >= 0 || currentUser.roles.indexOf( "curator" ) >= 0
  );
  const sortedNames = _.sortBy( names, [
    n => I18n.t( `lexicons.${_.snakeCase( n.lexicon )}`, { defaultValue: n.lexicon } ),
    n => n.position
  ] );
  const namesGroupedByPlace = { };
  const places = { };
  _.each( names, n => {
    if ( n.lexicon === "Scientific Names" ) {
      return;
    }
    _.each( n.place_taxon_names, ptn => {
      places[ptn.place.id] = ptn.place;
      namesGroupedByPlace[ptn.place_id] = namesGroupedByPlace[ptn.place_id] || [];
      namesGroupedByPlace[ptn.place_id].push( { ...n, position: ptn.position } );
    } );
  } );
  return (
    <Grid className="TaxonomyTab">
      <Row className="tab-section">
        <Col xs={12}>
          <Row>
            <Col xs={8}>
              <h3>{ I18n.t( "taxonomy" ) }</h3>
              <TaxonomicBranch
                taxon={taxon}
                chooseTaxon={t => showNewTaxon( t, { skipScrollTop: true } )}
                toggleAllChildrenShown={toggleAllChildrenShown}
                allChildrenShown={allChildrenShown}
                currentUser={currentUser}
                tabular
              />
            </Col>
            <Col xs={4}>
              <ul className="tab-links list-group">
                <li className="list-group-item internal">
                  <a
                    href={`/taxa/${taxon.id}/taxonomy_details`}
                    rel="nofollow"
                  >
                    <i className="fa fa-sitemap accessory-icon" />
                    { I18n.t( "taxonomy_details" ) }
                  </a>
                </li>
                <li className="list-group-item internal">
                  <a href={`/taxon_changes?taxon_id=${taxon.id}`}>
                    <span className="badge pull-right">
                      { I18n.toNumber( taxonChangesCount, { precision: 0 } ) }
                    </span>
                    <i className="fa fa-random accessory-icon" />
                    { I18n.t( "taxon_changes" ) }
                  </a>
                </li>
                <li className="list-group-item internal">
                  <a href={`/taxa/${taxon.id}/schemes`}>
                    <span className="badge pull-right">
                      { I18n.toNumber( taxonSchemesCount, { precision: 0 } ) }
                    </span>
                    <i className="glyphicon glyphicon-list-alt accessory-icon" />
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
                    { currentUser ? (
                      <th>{ I18n.t( "action" ) }</th>
                    ) : null }
                  </tr>
                </thead>
                <tbody>
                  { sortedNames.map( n => (
                    <tr
                      key={`taxon-names-${n.id}`}
                      className={n.is_valid ? "" : "outdated"}
                    >
                      <td>
                        { I18n.t( `lexicons.${_.snakeCase( n.lexicon )}`, { defaultValue: n.lexicon } ) }
                      </td>
                      <td
                        className={n.lexicon && _.snakeCase( n.lexicon ).match( /scientific/ ) ? "sciname" : "comname"}
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
              { _.isEmpty( namesGroupedByPlace ) ? null : (
                <div>
                  <h3>{ I18n.t( "regional_names" ) }</h3>
                  <UserText
                    text={I18n.t( "views.taxa.show.about_regional_names_desc" ).replace( /\n+/gm, " " )}
                  />
                  <table className="table table-striped regional-names">
                    <thead>
                      <tr>
                        <th>{ I18n.t( "place" ) }</th>
                        <th>{ I18n.t( "name" ) }</th>
                        <th>{ I18n.t( "language_slash_type" ) }</th>
                        { currentUser ? (
                          <th>{ I18n.t( "action" ) }</th>
                        ) : null }
                      </tr>
                    </thead>
                    <tbody>
                      { _.map( _.sortBy( _.keys( namesGroupedByPlace ), placeID => (
                        I18n.t( `places_name.${_.snakeCase( places[placeID].name )}`, { defaultValue: places[placeID].name } )
                      ) ), placeID => (
                        _.sortBy( namesGroupedByPlace[placeID], "position" ).map( n => (
                          <tr
                            key={`taxon-names-${n.id}`}
                            className={n.is_valid ? "" : "outdated"}
                          >
                            <td>
                              <a href={`/places/${placeID}`}>
                                { I18n.t( `places_name.${_.snakeCase( places[placeID].name )}`, { defaultValue: places[placeID].name } ) }
                              </a>
                            </td>
                            <td className="comname">
                              { n.name }
                            </td>
                            <td>
                              { I18n.t( `lexicons.${_.snakeCase( n.lexicon )}`, { defaultValue: n.lexicon } ) }
                            </td>
                            { currentUser ? (
                              <td>
                                { viewerIsCurator || n.creator_id === currentUser.id ? (
                                  <a href={`/taxon_names/${n.id}/edit`}>{ I18n.t( "edit" ) }</a>
                                ) : null }
                              </td>
                            ) : null }
                          </tr>
                        ) )
                      ) ) }
                    </tbody>
                  </table>
                </div>
              )}
              <h3 className={`text-center ${names.length > 0 ? "hidden" : ""}`}>
                <i className="fa fa-refresh fa-spin" />
              </h3>
            </Col>
            <Col xs={4}>
              <ul className="tab-links list-group">
                { viewerIsCurator ? (
                  <li className="list-group-item internal">
                    <a href={`/taxa/${taxon.id}/names`} rel="nofollow">
                      <i className="fa fa-gear accessory-icon" />
                      { I18n.t( "manage_names" ) }
                    </a>
                  </li>
                ) : null }
                <li className="list-group-item internal">
                  <a
                    href={`/taxa/${taxon.id}/taxon_names/new`}
                    rel="nofollow"
                  >
                    <i className="fa fa-plus accessory-icon" />
                    { I18n.t( "add_a_name" ) }
                  </a>
                </li>
              </ul>
              <h4>{ I18n.t( "about_names" ) }</h4>
              <UserText
                text={I18n.t( "views.taxa.show.about_names_desc" ).replace( /\n+/gm, " " )}
                truncate={400}
              />
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
