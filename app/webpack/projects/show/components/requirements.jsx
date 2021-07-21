import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
/* global TIMEZONE */

function dateToString( date, spansYears = false ) {
  let format;
  if ( date.match( /^\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{2} [+-]\d{1,2}:\d{2}/ ) ) {
    format = spansYears
      ? I18n.t( "momentjs.datetime_with_zone" )
      : I18n.t( "momentjs.datetime_with_zone_no_year" );
    return moment( date, "YYYY-MM-DD HH:mm Z" )
      .parseZone( ).tz( TIMEZONE ).format( format );
  }
  format = spansYears
    ? I18n.t( "momentjs.date_long" )
    : I18n.t( "momentjs.date_long_without_year" );
  return moment( date ).format( format );
}

const Requirements = ( {
  project, setSelectedTab, includeArrowLink, config
} ) => {
  const taxonRules = _.isEmpty( project.taxonRules ) ? I18n.t( "all_taxa_" )
    : _.map( _.sortBy( project.taxonRules, r => r.taxon.name ), r => (
      <SplitTaxon
        key={`project-taxon-rules-${r.id}`}
        user={config.currentUser}
        taxon={r.taxon}
        url={`/taxa/${r.taxon.id}`}
        noInactive
      />
    ) );
  const exceptTaxonRules = !_.isEmpty( project.notTaxonRules )
    && _.map( _.sortBy( project.notTaxonRules, r => r.taxon.name ), r => (
      <SplitTaxon
        key={`project-taxon-rules-${r.id}`}
        user={config.currentUser}
        taxon={r.taxon}
        url={`/taxa/${r.taxon.id}`}
        noInactive
      />
    ) );
  const locationRules = _.isEmpty( project.placeRules ) ? I18n.t( "worldwide" )
    : _.map( _.sortBy( project.placeRules, r => r.place.display_name ), r => (
      <a key={`project-place-rules-${r.id}`} href={`/places/${r.place.id}`}>
        { r.place.display_name }
      </a>
    ) );
  const exceptLocationRules = !_.isEmpty( project.notPlaceRules )
    && _.map( _.sortBy( project.notPlaceRules, r => r.place.display_name ), r => (
      <a key={`project-place-rules-${r.id}`} href={`/places/${r.place.id}`}>
        { r.place.display_name }
      </a>
    ) );
  let userRules;
  if ( _.isEmpty( project.userRules ) ) {
    userRules = project.rule_members_only ? I18n.t( "project_members_only" ) : I18n.t( "any_user" );
  } else {
    userRules = _.map( _.sortBy( project.userRules, r => r.user.login ), r => (
      <a key={`project-user-rules-${r.id}`} href={`/people/${r.user.login}`}>
        { r.user.login }
      </a>
    ) );
  }
  const exceptUserRules = !_.isEmpty( project.notUserRules )
    && _.map( _.sortBy( project.notUserRules, r => r.user.login ), r => (
      <a key={`project-user-rules-${r.id}`} href={`/people/${r.user.login}`}>
        { r.user.login }
      </a>
    ) );
  const projectRules = _.isEmpty( project.projectRules ) ? I18n.t( "any_project" )
    : _.map( _.sortBy( project.projectRules, r => r.project.title ), r => (
      <a key={`project-project-rules-${r.id}`} href={`/projects/${r.project.slug}`}>
        { r.project.title }
      </a>
    ) );
  const exceptProjectRules = !_.isEmpty( project.notProjectRules )
    && _.map( _.sortBy( project.notProjectRules, r => r.project.title ), r => (
      <a key={`project-project-rules-${r.id}`} href={`/projects/${r.project.slug}`}>
        { r.project.title }
      </a>
    ) );
  const qualityGradeRules = _.isEmpty( project.rule_quality_grade ) ? I18n.t( "any_quality_grade" )
    : _.map( _.keys( project.rule_quality_grade ),
      q => I18n.t( q === "research" ? "research_grade" : `${q}_` ) ).join( ", " );
  const media = [];
  if ( project.rule_photos ) {
    media.push( I18n.t( "photo" ) );
  }
  if ( project.rule_sounds ) {
    media.push( I18n.t( "sounds.sounds" ) );
  }
  const mediaRules = _.isEmpty( media ) ? I18n.t( "any_media" )
    : media.join( ` ${I18n.t( "and" )} ` );
  let dateRules = I18n.t( "any_date" );
  if ( project.rule_d1 && project.rule_d2 ) {
    const spansYears = true;
    dateRules = I18n.t( "date_to_date", {
      d1: dateToString( project.rule_d1, spansYears ),
      d2: dateToString( project.rule_d2, spansYears )
    } );
  } else if ( project.rule_observed_on ) {
    dateRules = dateToString( project.rule_observed_on );
  } else if ( project.rule_d1 ) {
    dateRules = I18n.t( "project_start_time_datetime", { datetime: dateToString( project.rule_d1 ) } );
  } else if ( project.rule_month ) {
    const monthIndices = project.rule_month.split( "," ).map( m => parseInt( m, 0 ) );
    dateRules = monthIndices.map( m => I18n.t( "date.month_names" )[m] ).join( ", " );
  }
  let establishmentRules = I18n.t( "any_establishment" );
  if ( project.rule_native || project.rule_introduced ) {
    establishmentRules = _.compact( [
      project.rule_native && I18n.t( "establishment.native" ),
      project.rule_introduced && I18n.t( "establishment.introduced" )
    ] ).join( ", " );
  }
  let annotationRequirement;
  if ( project.rule_term_id_instance ) {
    annotationRequirement = (
      <tr>
        <td className="param">
          <i className="fa fa-tag" />
          { I18n.t( "annotation" ) }
        </td>
        <td className="value">
          <a href={`/observations?term_id=${project.rule_term_id}`}>
            { I18n.t( `controlled_term_labels.${_.snakeCase( project.rule_term_id_instance.label )}`,
              { default: project.rule_term_id_instance.label } )
            }
          </a>
          { project.rule_term_value_id_instance && (
            <span className="term-value">
              <span className="separator">
                &rarr;
              </span>
              <a href={`/observations?term_id=${project.rule_term_id}&term_value_id=${project.rule_term_value_id}`}>
                { I18n.t( `controlled_term_labels.${_.snakeCase( project.rule_term_value_id_instance.label )}`,
                  { default: project.rule_term_value_id_instance.label } )
                }
              </a>
            </span>
          )}
        </td>
      </tr>
    );
  }
  let projectsRequirement;
  if ( !_.isEmpty( projectRules ) || !_.isEmpty( projectRules ) ) {
    projectsRequirement = (
      <tr>
        <td className="param">
          <i className="fa fa-briefcase" />
          { I18n.t( "projects" ) }
        </td>
        <td className="value">
          { projectRules }
          { exceptProjectRules && (
            <div className="except">
              <div className="bold">
                { I18n.t( "except" ) }
              </div>
              { exceptProjectRules }
            </div>
          ) }
        </td>
      </tr>
    );
  }
  const requirementContents = project.hasInsufficientRequirements( )
    ? I18n.t( "views.projects.show.this_project_has_not_defined_requirements" )
    : (
      <div>
        <div className="section-intro">
          { I18n.t( "label_colon", { label: I18n.t( "observations_in_this_project_must" ) } )}
        </div>
        <table>
          <tbody>
            <tr>
              <td className="param">
                <i className="fa fa-leaf" />
                { I18n.t( "taxa" ) }
              </td>
              <td className="value">
                { taxonRules }
                { exceptTaxonRules && (
                  <div className="except">
                    <div className="bold">
                      { I18n.t( "except" ) }
                    </div>
                    { exceptTaxonRules }
                  </div>
                ) }
              </td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-map-marker" />
                { I18n.t( "location" ) }
              </td>
              <td className="value location-rules">
                { locationRules }
                { exceptLocationRules && (
                  <div className="except">
                    <div className="bold">
                      { I18n.t( "except" ) }
                    </div>
                    { exceptLocationRules }
                  </div>
                ) }
              </td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-user" />
                { I18n.t( "users" ) }
              </td>
              <td className="value">
                { userRules }
                { exceptUserRules && (
                  <div className="except">
                    <div className="bold">
                      { I18n.t( "except" ) }
                    </div>
                    { exceptUserRules }
                  </div>
                ) }
              </td>
            </tr>
            { projectsRequirement }
            <tr>
              <td className="param">
                <i className="fa fa-certificate" />
                { I18n.t( "quality_grade_" ) }
              </td>
              <td className="value">{ qualityGradeRules }</td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-file-image-o" />
                { I18n.t( "media_type" ) }
              </td>
              <td className="value">{ mediaRules }</td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-calendar" />
                { I18n.t( "date_" ) }
              </td>
              <td className="value">{ dateRules }</td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-globe" />
                { I18n.t( "establishment.establishment" ) }
              </td>
              <td className="value">{ establishmentRules }</td>
            </tr>
            { annotationRequirement }
          </tbody>
        </table>
      </div> );
  return (
    <div className="Requirements">
      <h2>
        { I18n.t( "project_requirements" ) }
        { includeArrowLink && (
          <button
            type="button"
            className="btn btn-nostyle"
            onClick={( ) => setSelectedTab( "about" )}
          >
            <i className="fa fa-arrow-circle-right" />
          </button>
        ) }
      </h2>
      { requirementContents }
    </div>
  );
};

Requirements.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setSelectedTab: PropTypes.func,
  includeArrowLink: PropTypes.bool
};

export default Requirements;
