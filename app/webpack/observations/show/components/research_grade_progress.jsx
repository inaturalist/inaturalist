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
          switch ( type ) {
            case "date":
              return ( <li><i className="fa fa-calendar" />Specify Date</li> );
            case "location":
              return ( <li><i className="fa fa-map-marker" />Specify Location</li> );
            case "media":
              return ( <li><i className="fa fa-file-image-o" />Add photos or sounds</li> );
            case "ids":
              return ( <li><i className="fa icon-identification" />Community Identification</li> );
            case "rank":
              return ( <li><i className="fa fa-leaf" />More specific ID</li> );
            case "metric-date":
              return ( <li><i className="fa fa-calendar-check-o" />Accurate Date</li> );
            case "metric-location":
              return ( <li><i className="fa fa-bullseye" />Accurate Location</li> );
            case "metric-wild":
              return ( <li><i className="fa fa-bolt" />Wild Organism</li> );
            case "metric-evidence":
              return ( <li><i className="fa fa-bolt" />Evidence of an Organism</li> );
            case "metric-recent":
              return ( <li><i className="fa fa-bolt" />Recent Evidence</li> );
            case "metric-needs_id":
              return ( <li><i className="fa fa-gavel" />Community Agreement</li> );
            default:
              return null;
          }
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
