import _ from "lodash";
import React, { PropTypes } from "react";



class ResearchGradeProgress extends React.Component {

  constructor( ) {
    super( );
    this.criteriaList = this.criteriaList.bind( this );
  }

  outlinkIcon( source ) {
    switch ( source ) {
      case "Atlas of Living Australia":
        return "/assets/sites/ala.png";
      case "Calflora":
        return "/assets/sites/calflora.png";
      case "GBIF":
        return "/assets/sites/gbif.png";
      case "GloBI":
        return "/assets/sites/globi.png";
      default:
        return null;
    }
  }

  criteriaList( ) {
    const { observation, qualityMetrics } = this.props;
    let remainingCriteria = { };
    const passedCriteria = { };
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
      } else if ( score > 0 ) {
        passedCriteria[`metric-${metric}`] = true;
      }
    } );
    remainingCriteria.flags = observation.flags.length > 0;
    if ( observation.taxon && observation.taxon.rank_level === 20 ) {
      remainingCriteria.rank = false;
      if ( !passedCriteria["metric-needs_id"] ) {
        remainingCriteria["metric-needs_id"] = false;
        remainingCriteria.rank_or_needs_id = true;
      }
    }
    remainingCriteria = _.pickBy( remainingCriteria, bool => ( bool === true ) );
    return (
      <ul className="remaining">
        { _.map( remainingCriteria, ( bool, type ) => {
          if ( type === "rank_or_needs_id" ) {
            return (
              <li
                key="need-rank_or_needs_id"
                className={ _.size( remainingCriteria ) > 1 ? "top_border" : "" }
              >
                <div className="reason">
                  <div className="reason_icon">
                    <i className="fa fa-leaf" />
                  </div>
                  <div className="reason_label">
                    Community ID as species level or lower
                  </div>
                </div>
                <div className="or">
                  - OR -
                </div>
                <div className="reason">
                  <div className="reason_icon">
                    <i className="fa fa-gavel" />
                  </div>
                  <div className="reason_label">
                    The community must feel that the Community ID is the best
                    it can be based on the evidence
                  </div>
                </div>
              </li>
            );
          }
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
              label = "Community ID as species level or lower";
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
              label = "The community must feel that the Community ID is the best it can be based on the evidence";
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
              <div className="reason_icon">
                <i className={ `fa ${icon}` } />
              </div>
              <div className="reason_label">{ label }</div>
            </li>
          );
        } ) }
      </ul>
    );
  }

  render( ) {
    const observation = this.props.observation;
    if ( !observation ) { return ( <div /> ); }
    const grade = observation.quality_grade;
    const needsIDActive = ( grade === "needs_id" || grade === "research" );
    let description;
    let criteria;
    let outlinks;
    if ( grade === "research" ) {
      description = (
        <span>
          <span className="bold">This observation is Research Grade! </span>
          It can now be used for research and featured on other websites.
        </span>
      );
    } else {
      criteria = this.criteriaList( );
      description = (
        <span>
          The below items are needed to achieve <span className="bold">Research Grade:</span>
        </span>
      );
    }
    if ( observation.outlinks && observation.outlinks.length > 0 ) {
      outlinks = ( <div className="outlinks">
        <span className="intro">
          This observation is featured on { observation.outlinks.length } sites
          { grade !== "research" ? (
            <span className="intro-sub">
              Please allow a few weeks for external sites to sync changes from this site
            </span>
          ) : "" }
        </span>
        { observation.outlinks.map( ol => (
          <div className="outlink" key={ `outlink-${ol.source}` }>
            <a href={ ol.url }>
              <div className="squareIcon">
                <img src={ this.outlinkIcon( ol.source ) } />
              </div>
              <div className="title">{ ol.source }</div>
            </a>
          </div>
        ) ) }
      </div> );
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
        { outlinks }
      </div>
    );
  }
}

ResearchGradeProgress.propTypes = {
  observation: PropTypes.object,
  qualityMetrics: PropTypes.object
};

export default ResearchGradeProgress;
