import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Col } from "react-bootstrap";
/* global OUTLINK_SITES */

class ResearchGradeProgress extends React.Component {
  constructor( ) {
    super( );
    const criteria = ["date", "location", "media", "ids", "metric-date",
      "metric-location", "metric-wild", "metric-evidence", "metric-recent",
      "metric-subject", "rank", "flags", "rank_or_needs_id"];
    this.criteriaOrder = _.zipObject( criteria, [...Array( criteria.length ).keys( )] );
  }

  criteriaList( ) {
    const { observation, qualityMetrics } = this.props;
    let remainingCriteria = { };
    const passedCriteria = { };
    remainingCriteria.date = !observation.observed_on;
    remainingCriteria.media = (
      ( observation.photos ? observation.photos.length : 0 )
      + ( observation.sounds ? observation.sounds.length : 0 )
    ) === 0;
    remainingCriteria.rank = ( observation.taxon && observation.taxon.rank_level > 10 );
    remainingCriteria.ids = !observation.identifications_most_agree;
    remainingCriteria.location = !( observation.geojson || observation.obscured );
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
    const unresolvedFlags = _.filter( observation.flags || [], f => !f.resolved );
    remainingCriteria.flags = unresolvedFlags.length > 0;
    if ( observation.taxon && observation.taxon.rank_level === 20 ) {
      remainingCriteria.rank = false;
      if ( !passedCriteria["metric-needs_id"] ) {
        remainingCriteria["metric-needs_id"] = false;
        remainingCriteria.rank_or_needs_id = true;
      }
    }
    remainingCriteria["hidden-media"] = _.some( _.flatten( [observation.photos, observation.sounds] ), "hidden" );
    remainingCriteria = _.pickBy( remainingCriteria, bool => ( bool === true ) );
    const sortedCriteria = _.sortBy( _.map(
      remainingCriteria,
      ( bool, type ) => ( { type, bool } )
    ), c => (
      this.criteriaOrder[c.type]
    ) );
    return (
      <ul className="remaining">
        { _.map( sortedCriteria, c => {
          const { type } = c;
          if ( type === "rank_or_needs_id" ) {
            return (
              <li
                key="need-rank_or_needs_id"
                className={_.size( remainingCriteria ) > 1 ? "top_border" : ""}
              >
                <div className="reason">
                  <div className="reason_icon">
                    <i className="fa fa-leaf" />
                  </div>
                  <div className="reason_label">
                    { I18n.t( "community_id_is_precise" ) }
                  </div>
                </div>
                <div className="or">
                  { `- ${I18n.t( "or" )} -` }
                </div>
                <div className="reason">
                  <div className="reason_icon">
                    <i className="fa fa-gavel" />
                  </div>
                  <div className="reason_label">
                    { I18n.t( "the_community_must_feel_that" ) }
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
              label = I18n.t( "date_specified" );
              break;
            case "location":
              icon = "fa-map-marker";
              label = I18n.t( "location_specified" );
              break;
            case "media":
              icon = "fa-file-image-o";
              label = I18n.t( "has_photos_or_sounds" );
              break;
            case "ids":
              icon = "icon-identification";
              label = I18n.t( "has_id_supported_by_two_or_more" );
              break;
            case "rank":
              icon = "fa-leaf";
              label = I18n.t( "community_id_is_precise" );
              break;
            case "metric-date":
              icon = "fa-calendar-check-o";
              label = I18n.t( "date_is_accurate" );
              break;
            case "metric-location":
              icon = "fa-bullseye";
              label = I18n.t( "location_is_accurate" );
              break;
            case "metric-wild":
              icon = "icon-icn-wild";
              label = I18n.t( "organism_is_wild" );
              break;
            case "metric-evidence":
              icon = "icon-icn-dna";
              label = I18n.t( "evidence_of_organism" );
              break;
            case "metric-subject":
              icon = "icon-icn-subject";
              label = I18n.t( "evidence_related_to_single_subject" );
              break;
            case "metric-recent":
              icon = "fa-clock-o";
              label = I18n.t( "recent_evidence_of_organism" );
              break;
            case "metric-needs_id":
              icon = "fa-gavel";
              label = I18n.t( "the_community_must_feel_that" );
              break;
            case "flags":
              icon = "fa-flag danger";
              label = I18n.t( "all_flags_must_be_resolved" );
              break;
            case "hidden-media":
              icon = "fa-eye-slash danger";
              label = I18n.t( "all_media_must_be_unhidden" );
              break;
            default:
              return null;
          }
          return (
            <li key={`need-${type}`}>
              <div className="reason_icon">
                <i className={`fa ${icon}`} />
              </div>
              <div className="reason_label">{ label }</div>
            </li>
          );
        } ) }
      </ul>
    );
  }

  render( ) {
    const { config, observation } = this.props;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    const grade = observation.quality_grade;
    const needsIDActive = ( grade === "needs_id" || grade === "research" );
    let description;
    let criteria;
    let outlinks;
    const viewerIsObserver = config.currentUser && config.currentUser.id === observation.user.id;
    if ( grade === "research" ) {
      description = (
        <span>
          <span className="bold">
            { I18n.t( "this_observation_is_research_grade" ) }
          </span>
          { " " }
          {
            observation.license_code
              ? I18n.t( "it_can_now_be_used_for_research" )
              : I18n.t( "however_not_licensed" )
          }
          { !observation.license_code && viewerIsObserver && (
            <span
              dangerouslySetInnerHTML={{
                __html: I18n.t( "however_not_licensed_action_html" )
              }}
            />
          ) }
        </span>
      );
    } else {
      criteria = this.criteriaList( );
      description = (
        <span
          dangerouslySetInnerHTML={{ __html: I18n.t( "the_below_items_are_needed_to_achieve" ) }}
        />
      );
    }
    if ( observation.outlinks && observation.outlinks.length > 0 ) {
      outlinks = (
        <div className="outlinks">
          <span className="intro">
            { I18n.t(
              "this_observation_is_featured_on_x_sites",
              { count: observation.outlinks.length }
            ) }
            { grade !== "research" && (
              <span className="intro-sub">
                { I18n.t( "please_allow_a_few_weeks_for_external_sites" ) }
              </span>
            ) }
          </span>
          { observation.outlinks.map( ol => (
            <div className="outlink" key={`outlink-${ol.source}`}>
              <a href={ol.url}>
                <div className="squareIcon">
                  <img alt={ol.source} src={OUTLINK_SITES[ol.source].icon} />
                </div>
                <div className="title">{ ol.source }</div>
              </a>
            </div>
          ) ) }
        </div>
      );
    }
    return (
      <div className="ResearchGradeProgress">
        <div className="graphic">
          <div className="separators">
            <Col xs={6} className="left">
              <div className={`separator ${needsIDActive ? "active" : "incomplete"}`} />
            </Col>
            <Col xs={6} className="right">
              <div className={`separator ${grade === "research" ? "active" : "incomplete"}`} />
            </Col>
          </div>
          <div className="checks clearfix">
            <Col xs={4}>
              <div className="check casual active">
                <i className="fa fa-check" />
              </div>
            </Col>
            <Col xs={4}>
              <div className={`check needs-id ${needsIDActive ? "active" : "incomplete"}`}>
                <i className="fa fa-check" />
              </div>
            </Col>
            <Col xs={4}>
              <div className={`check research ${grade === "research" ? "active" : "incomplete"}`}>
                <i className="fa fa-check" />
              </div>
            </Col>
          </div>
          <div className="labels">
            <div className={`casual ${grade === "casual" && "active"}`}>
              { I18n.t( "casual_" ) }
            </div>
            <div className={`needs-id ${grade === "needs_id" && "active"}`}>
              { I18n.t( "needs_id_" ) }
            </div>
            <div className={`research ${grade === "research" && "active"}`}>
              { I18n.t( "research_grade" ) }
            </div>
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
  config: PropTypes.object,
  observation: PropTypes.object,
  qualityMetrics: PropTypes.object
};

export default ResearchGradeProgress;
