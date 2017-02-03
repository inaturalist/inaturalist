import _ from "lodash";
import React, { PropTypes } from "react";
import UsersPopover from "./users_popover";

class QualityMetrics extends React.Component {
  constructor( ) {
    super( );
    this.voteCellsForMetric = this.voteCellsForMetric.bind( this );
  }

  voteCell( metric, isAgree, isMajority, className, usersChoice, voters ) {
    return (
      <span>
        <span className="check">
          { isMajority ? (
            <i className="fa fa-check" />
          ) : null }
        </span>
        <i className={ `fa ${className}` } onClick={ () => {
          if ( usersChoice ) {
            this.props.unvoteMetric( metric );
          } else {
            if ( isAgree ) {
              this.props.voteMetric( metric );
            } else {
              this.props.voteMetric( metric, { agree: "false" } );
            }
          }
        } }
        />
        <span className="count">
          <UsersPopover
            users={ voters }
            keyPrefix={ `metric-${metric}` }
            contents={ ( <span>({voters.length})</span> ) }
          />
        </span>
      </span>
    );
  }

  voteCellsForMetric( metric ) {
    const votersFor = [];
    const votersAgainst = [];
    let userVotedFor;
    let userVotedAgainst;
    const config = this.props.config;
    const loggedIn = config && config.currentUser;
    _.each( this.props.qualityMetrics[metric], m => {
      if ( m.agree ) {
        votersFor.push( m.user );
      } else {
        votersAgainst.push( m.user );
      }
      if ( loggedIn && m.user.id === config.currentUser.id ) {
        userVotedFor = m.agree;
        userVotedAgainst = !m.agree;
      }
    } );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    let mostAgree = votersFor.length > votersAgainst.length;
    const mostDisagree = votersAgainst.length > votersFor.length;
    if ( _.isEmpty( this.props.qualityMetrics[metric] ) ) {
      mostAgree = true;
    }

    return {
      agreeCell: this.voteCell(
        metric, true, mostAgree, agreeClass, userVotedFor, votersFor ),
      disagreeCell: this.voteCell(
        metric, false, mostDisagree, disagreeClass, userVotedAgainst, votersAgainst )
    };
  }

  render( ) {
    const observation = this.props.observation;
    const checkIcon = ( <i className="fa fa-check check" /> );
    const hasMedia = ( observation.photos.length + observation.sounds.length ) > 0;
    const atLeastSpecies = ( observation.taxon && observation.taxon.rank_level <= 10 );
    const mostAgree = observation.identifications_most_agree;
    const wildCells = this.voteCellsForMetric( "wild" );
    const locationCells = this.voteCellsForMetric( "location" );
    const dateCells = this.voteCellsForMetric( "date" );
    const evidenceCells = this.voteCellsForMetric( "evidence" );
    const recentCells = this.voteCellsForMetric( "recent" );
    return (
      <div className="QualityMetrics">
        <h3>Data Quality Assessment</h3>
        <div className="grade">
          Quality Grade:
          <span className={ `quality_grade ${observation.quality_grade} ` }>
            { observation.quality_grade }
          </span>
        </div>
        <div className="text">
          The data quality assessment is an evaluation of an observation’s accuracy.
          Research Grade observations may be used by scientists for research. Cast your vote below:
        </div>
        <table className="table">
          <thead>
            <tr>
              <th>Research Grade Qualification</th>
              <th className="agree">Yes</th>
              <th className="disagree">No</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td className="metric_title">
                <i className="fa fa-calendar" />
                Date specified
              </td>
              <td className="agree">{ observation.observed_on ? checkIcon : null }</td>
              <td className="disagree">{ observation.observed_on ? null : checkIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-map-marker" />
                Location specified
              </td>
              <td className="agree">{ observation.location ? checkIcon : null }</td>
              <td className="disagree">{ observation.location ? null : checkIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-file-image-o" />
                Has photos or sounds
              </td>
              <td className="agree">{ hasMedia ? checkIcon : null }</td>
              <td className="disagree">{ hasMedia ? null : checkIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa icon-identification" />
                Has ID supported by two or more
              </td>
              <td className="agree">{ mostAgree ? checkIcon : null }</td>
              <td className="disagree">{ mostAgree ? null : checkIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-leaf" />
                Community ID as species level or lower
              </td>
              <td className="agree">{ atLeastSpecies ? checkIcon : null }</td>
              <td className="disagree">{ atLeastSpecies ? null : checkIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-calendar-check-o" />
                Date is accurate
              </td>
              <td className="agree">{ dateCells.agreeCell }</td>
              <td className="disagree">{ dateCells.disagreeCell }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-bullseye" />
                Location is accurate
              </td>
              <td className="agree">{ locationCells.agreeCell }</td>
              <td className="disagree">{ locationCells.disagreeCell }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-gavel" />
                Community can confirm/improve ID
              </td>
              <td className="agree"></td>
              <td className="disagree"></td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-bolt" />
                Organism is wild
              </td>
              <td className="agree">{ wildCells.agreeCell }</td>
              <td className="disagree">{ wildCells.disagreeCell }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-flag" />
                Content is appropriate for site
              </td>
              <td className="agree"></td>
              <td className="disagree"></td>
            </tr>
          </tbody>
        </table>
      </div>
    );
  }
}

QualityMetrics.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  qualityMetrics: PropTypes.object,
  voteMetric: PropTypes.func,
  unvoteMetric: PropTypes.func
};

export default QualityMetrics;
