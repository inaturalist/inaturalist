import _ from "lodash";
import React, { PropTypes } from "react";

const ResearchGradeProgress = ( { observation, qualityMetrics } ) => {
  if ( !observation ) { return ( <div /> ); }
  const grade = observation.quality_grade;
  const needsIDActive = ( grade === "needs_id" || grade === "research" );
  let description;
  let criteria;
  if ( grade === "research" ) {
    description = (
      <span>
        <span className="bold">This observation is Research Grade! </span>
        It can now be used for research and featured on other websites.
      </span>
    );
  } else {
    const remainingCriteria = { };
    remainingCriteria.date = !observation.observed_on;
    remainingCriteria.media = ( observation.photos.length + observation.sounds.length ) === 0;
    remainingCriteria.rank = ( observation.taxon && observation.taxon.rank_level > 10 );
    remainingCriteria.ids = !observation.identifications_most_agree;
    remainingCriteria.location = !observation.location;
    remainingCriteria.flags = observation.flags.length > 0;
    const votesFor = { };
    const votesAgainst = { };
    _.each( qualityMetrics, ( values, metric ) => {
      _.each( values, v => {
        const agree = ( "vote_scope" in v ) ? !v.vote_flag : v.agree;
        if ( agree ) {
          votesFor[metric] = votesFor[metric] || 0;
          votesFor[metric] += 1;
        } else {
          votesAgainst[metric] = votesAgainst[metric] || 0;
          votesAgainst[metric] += 1;
        }
      } );
    } );
    _.each( qualityMetrics, ( values, metric ) => {
      const score = ( votesFor[metric] || 0 ) - ( votesAgainst[metric] || 0 );
      if ( score < 0 ) {
        remainingCriteria[`metric-${metric}`] = true;
      }
    } );
    criteria = (
      <ul className="remaining">
        { _.map( remainingCriteria, ( bool, type ) => {
          if ( bool !== true ) { return null; }
          let icon;
          let label;
          switch ( type ) {
            case "date":
              icon = "fa-calendar";
              label = "Specify Date";
              break;
            case "location":
              icon = "fa-map-marker";
              label = "Specify Location";
              break;
            case "media":
              icon = "fa-file-image-o";
              label = "Add photos or sounds";
              break;
            case "ids":
              icon = "icon-identification";
              label = "Community Identification";
              break;
            case "rank":
              icon = "fa-leaf";
              label = "More specific ID";
              break;
            case "metric-date":
              icon = "fa-calendar-check-o";
              label = "Accurate Date";
              break;
            case "metric-location":
              icon = "fa-bullseye";
              label = "Accurate Location";
              break;
            case "metric-wild":
              icon = "fa-bolt";
              label = "Wild Organism";
              break;
            case "metric-evidence":
              icon = "fa-bolt";
              label = "Evidence of an Organism";
              break;
            case "metric-recent":
              icon = "fa-bolt";
              label = "Recent Evidence";
              break;
            case "metric-needs_id":
              icon = "fa-gavel";
              label = "Community Agreement";
              break;
            case "flags":
              icon = "fa-flag danger";
              label = "All flags must be resolved";
              break;
            default:
              return null;
          }
          return (
            <li key={ `need-${type}` }>
              <i className={ `fa ${icon}` } />{ label }
            </li>
          );
        } ) }
      </ul>
    );
    description = (
      <span>
        The below items are needed to achieve <span className="bold">Research Grade:</span>
      </span>
    );
  }
  return (
    <div className="ResearchGradeProgress">
      <div className="graphic">
        <div className="checks">
          <div className="check active">
            <i className="fa fa-check" />
          </div>
          <div className={ `separator ${needsIDActive ? "active" : "incomplete"}` } />
          <div className={ `check needs-id ${needsIDActive ? "active" : "incomplete"}` }>
            <i className="fa fa-check" />
          </div>
          <div className={ `separator ${grade === "research" ? "active" : "incomplete"}` } />
          <div className={ `check research ${grade === "research" ? "active" : "incomplete"}` }>
            <i className="fa fa-check" />
          </div>
        </div>
        <div className="labels">
          <div className={ `casual ${grade === "casual" && "active"}` }>Casual Grade</div>
          <div className={ `needs-id ${grade === "needs_id" && "active"}` }>Needs ID</div>
          <div className={ `research ${grade === "research" && "active"}` }>Research Grade</div>
        </div>
      </div>
      <div className="info">
        { description }
      </div>
      { criteria }
      <div className="links">
      </div>
    </div>
  );
};

ResearchGradeProgress.propTypes = {
  observation: PropTypes.object,
  qualityMetrics: PropTypes.object
};

export default ResearchGradeProgress;
