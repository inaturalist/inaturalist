import _ from "lodash";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

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
  return (
    <div className="Requirements">
      <h2>
        Project Requirements
        <i className="fa fa-arrow-circle-right" />
      </h2>
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
        </tbody>
      </table>
    </div>
  );
};

Requirements.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  leaders: PropTypes.array,
  type: PropTypes.string
};

export default Requirements;
