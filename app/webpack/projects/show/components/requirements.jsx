import _ from "lodash";
import React, { PropTypes } from "react";
import moment from "moment-timezone";
import SplitTaxon from "../../../shared/components/split_taxon";
/* global TIMEZONE */

function dateToString( date ) {
  if ( date.match( /^\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{2} [+-]\d{1,2}:\d{2}/ ) ) {
    return moment( date, "YYYY-MM-DD HH:mm Z" ).
      parseZone( ).tz( TIMEZONE ).format( "MMMM D h:mma z" );
  }
  return moment( date ).format( "MMMM D" );
}

const Requirements = ( { project, setSelectedTab, includeArrowLink, config } ) => {
  const taxonRules = _.isEmpty( project.taxonRules ) ? I18n.t( "all_taxa_" ) :
    _.map( project.taxonRules, r => (
      <SplitTaxon
        user={ config.currentUser }
        key={ `requirement_taxon_${r.taxon.id}` }
        taxon={ r.taxon }
      />
    ) );
  const projectRules = _.isEmpty( project.projectRules ) ? I18n.t( "any" ) :
    _.map( project.projectRules, r => r.project.title ).join( ", " );
  const locationRules = _.isEmpty( project.placeRules ) ? I18n.t( "worldwide" ) :
    _.map( project.placeRules, r => r.place.display_name ).join( ", " );
  const userRules = _.isEmpty( project.userRules ) ? I18n.t( "any" ) :
    _.map( project.userRules, r => r.user.login ).join( ", " );
  const qualityGradeRules = _.isEmpty( project.rule_quality_grade ) ? I18n.t( "any" ) :
    _.map( _.keys( project.rule_quality_grade ), q =>
      I18n.t( q === "research" ? "research_grade" : q )
    ).join( ", " );
  const media = [];
  if ( project.rule_photos ) {
    media.push( I18n.t( "photo" ) );
  }
  if ( project.rule_sounds ) {
    media.push( I18n.t( "sounds.sounds" ) );
  }
  const mediaRules = _.isEmpty( media ) ? I18n.t( "any" ) :
    media.join( ` ${I18n.t( "and" )} ` );
  let dateRules = I18n.t( "any" );
  if ( project.rule_d1 && project.rule_d2 ) {
    dateRules = `${dateToString( project.rule_d1 )} ${I18n.t( "to" )} ${dateToString( project.rule_d2 )}`;
  } else if ( project.rule_observed_on ) {
    dateRules = dateToString( project.rule_observed_on );
  }
  return (
    <div className="Requirements">
      <h2>
        { I18n.t( "project_requirements" ) }
        { includeArrowLink && (
          <i
            className="fa fa-arrow-circle-right"
            onClick={ ( ) => setSelectedTab( "about" ) }
          />
        ) }
      </h2>
      <div className="section-intro">
        { I18n.t( "observations_in_this_project_must" ) }:
      </div>
      <table>
        { project.is_umbrella ? (
          <tbody>
            <tr>
              <td className="param">
                <i className="fa fa-briefcase" />
                { I18n.t( "projects" ) }
              </td>
              <td className="value">{ projectRules }</td>
            </tr>
          </tbody>
        ) : (
          <tbody>
            <tr>
              <td className="param">
                <i className="fa fa-leaf" />
                { I18n.t( "taxa" ) }
              </td>
              <td className="value">{ taxonRules }</td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-map-marker" />
                { I18n.t( "location" ) }
              </td>
              <td className="value">{ locationRules }</td>
            </tr>
            <tr>
              <td className="param">
                <i className="fa fa-user" />
                { I18n.t( "users" ) }
              </td>
              <td className="value">{ userRules }</td>
            </tr>
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
          </tbody>
        ) }
      </table>
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
