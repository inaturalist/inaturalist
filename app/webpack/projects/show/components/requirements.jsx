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

const Requirements = ( { project } ) => {
  const taxonRules = _.isEmpty( project.taxonRules ) ? "All taxa" :
    _.map( project.taxonRules, r => (
      <SplitTaxon key={ `requirement_taxon_${r.taxon.id}` } taxon={ r.taxon } />
    ) );
  const locationRules = _.isEmpty( project.placeRules ) ? "Worldwide" :
    _.map( project.placeRules, r => r.place.display_name ).join( ", " );
  const userRules = _.isEmpty( project.userRules ) ? "Any" :
    _.map( project.userRules, r => r.user.login ).join( ", " );
  const qualityGradeRules = _.isEmpty( project.rule_quality_grade ) ? "Any" :
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
  const mediaRules = _.isEmpty( media ) ? "Any" :
    media.join( " and " );
  let dateRules = "Any";
  if ( project.rule_d1 && project.rule_d2 ) {
    dateRules = `${dateToString( project.rule_d1 )} to ${dateToString( project.rule_d2 )}`;
  } else if ( project.rule_observed_on ) {
    dateRules = dateToString( project.rule_observed_on );
  }
  return (
    <div className="Requirements">
      <table>
        <tbody>
          <tr>
            <td className="param">
              <i className="fa fa-leaf" />
              Taxa
            </td>
            <td className="value">{ taxonRules }</td>
          </tr>
          <tr>
            <td className="param">
              <i className="fa fa-map-marker" />
              Location
            </td>
            <td className="value">{ locationRules }</td>
          </tr>
          <tr>
            <td className="param">
              <i className="fa fa-user" />
              Users
            </td>
            <td className="value">{ userRules }</td>
          </tr>
          <tr>
            <td className="param">
              <i className="fa fa-certificate" />
              Quality Grade
            </td>
            <td className="value">{ qualityGradeRules }</td>
          </tr>
          <tr>
            <td className="param">
              <i className="fa fa-file-image-o" />
              Media Type
            </td>
            <td className="value">{ mediaRules }</td>
          </tr>
          <tr>
            <td className="param">
              <i className="fa fa-calendar" />
              Date
            </td>
            <td className="value">{ dateRules }</td>
          </tr>
        </tbody>
      </table>
    </div>
  );
};

Requirements.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object
};

export default Requirements;
