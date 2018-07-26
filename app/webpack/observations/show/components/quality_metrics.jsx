import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { OverlayTrigger, Popover } from "react-bootstrap";
import FlagAnItemContainer from "../../../shared/containers/flag_an_item_container";
import UsersPopover from "./users_popover";
/* global SITE */

class QualityMetrics extends React.Component {
  constructor( ) {
    super( );
    this.voteCellsForMetric = this.voteCellsForMetric.bind( this );
    this.needsIDRow = this.needsIDRow.bind( this );
  }

  popover( ) {
    return (
      <Popover
        className="DataQualityOverlay PopoverWithHeader"
        id="popover-data-quality"
      >
        <div className="header">
          { I18n.t( "data_quality_assessment" ) }
        </div>
        <div className="contents" dangerouslySetInnerHTML={ { __html:
          I18n.t( "views.observations.show.quality_assessment_help_html", {
            site_name: SITE.short_name } ) } }
        />
      </Popover>
    );
  }

  voteCell( metric, isAgree, isMajority, className, usersChoice, voters, loading, disabled ) {
    const config = this.props.config;
    let votesCount = loading ? (
      <div className="loading_spinner" /> ) : (
      <UsersPopover
        users={ voters }
        keyPrefix={ `metric-${metric}` }
        contents={ ( <span>{voters.length === 0 ? null : voters.length}</span> ) }
      /> );
    const thumb = config && config.currentUser ? (
      <i className={ `fa ${className}` } onClick={ () => {
        if ( disabled ) { return; }
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
      /> ) : null;
    return (
      <span>
        <span className="check">
          { isMajority ? (
            <i className={ `fa ${isAgree ? "fa-check" : "fa-times"}` } />
          ) : null }
        </span>
        { thumb }
        <span className="count">{ votesCount }</span>
      </span>
    );
  }

  needsIDRow( ) {
    const config = this.props.config;
    const loggedIn = config && config.currentUser;
    const needsIDInfo = this.infoForMetric( "needs_id" );
    if ( !loggedIn &&
          _.isEmpty( needsIDInfo.votersFor ) &&
          _.isEmpty( needsIDInfo.votersAgainst ) ) {
      return null;
    }
    let votesForCount = needsIDInfo.voteForLoading ? (
      <div className="loading_spinner" /> ) : (
      <UsersPopover
        users={ needsIDInfo.votersFor }
        keyPrefix="metric-needs_id-agree"
        contents={ <span>({needsIDInfo.votersFor.length})</span> }
      /> );
    let votesAgainstCount = needsIDInfo.voteAgainstLoading ? (
      <div className="loading_spinner" /> ) : (
      <UsersPopover
        users={ needsIDInfo.votersAgainst }
        keyPrefix="metric-needs_id-disagree"
        contents={ <span>({needsIDInfo.votersAgainst.length})</span> }
      /> );
    let checkboxYes = loggedIn ? (
      <input type="checkbox" id="improveYes"
        disabled={ needsIDInfo.loading }
        checked={ needsIDInfo.userVotedFor }
        onChange={ () => {
          if ( needsIDInfo.userVotedFor ) {
            this.props.unvoteMetric( "needs_id" );
          } else {
            this.props.voteMetric( "needs_id" );
          }
        } }
      /> ) : null;
    let checkboxNo = loggedIn ? (
      <input type="checkbox" id="improveNo"
        disabled={ needsIDInfo.loading }
        checked={ needsIDInfo.userVotedAgainst }
        onChange={ () => {
          if ( needsIDInfo.userVotedAgainst ) {
            this.props.unvoteMetric( "needs_id" );
          } else {
            this.props.voteMetric( "needs_id", { agree: "false" } );
          }
        } }
      /> ) : null;
    return (
      <tr className="improve">
        <td className="metric_title" colSpan={ 3 }>
          <i className="fa fa-gavel" />
          { I18n.t( "based_on_the_evidence_can_id_be_improved" ) }
          <div className="inputs">
            <div className="yes">
              { checkboxYes }
              <label htmlFor="improveYes" className={ needsIDInfo.mostAgree ? "bold" : "" }>
                { I18n.t( "yes" ) }
              </label> { votesForCount }
            </div>
            <div className="no">
              { checkboxNo }
              <label htmlFor="improveNo" className={ needsIDInfo.mostDisagree ? "bold" : "" }>
                { I18n.t( "no_its_as_good_as_it_can_be" ) }
              </label> { votesAgainstCount }
            </div>
          </div>
        </td>
      </tr>
    );
  }

  infoForMetric( metric ) {
    const votersFor = [];
    const votersAgainst = [];
    let userVotedFor;
    let userVotedAgainst;
    let voteForLoading;
    let voteAgainstLoading;
    const config = this.props.config;
    const loggedIn = config && config.currentUser;
    _.each( this.props.qualityMetrics[metric], m => {
      const agree = ( "vote_scope" in m ) ? m.vote_flag : m.agree;
      if ( agree ) {
        votersFor.push( m.user || { } );
        if ( m.api_status ) { voteForLoading = true; }
      } else {
        votersAgainst.push( m.user || { } );
        if ( m.api_status ) { voteAgainstLoading = true; }
      }
      if ( loggedIn && m.user && m.user.id === config.currentUser.id ) {
        userVotedFor = agree;
        userVotedAgainst = !agree;
      }
    } );
    const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
    const disagreeClass = userVotedAgainst ? "fa-thumbs-down" : "fa-thumbs-o-down";
    let mostAgree = votersFor.length > votersAgainst.length;
    const mostDisagree = votersAgainst.length > votersFor.length;
    if ( _.isEmpty( this.props.qualityMetrics[metric] ) && metric !== "needs_id" ) {
      mostAgree = true;
    }
    return {
      mostAgree,
      mostDisagree,
      agreeClass,
      disagreeClass,
      userVotedFor,
      userVotedAgainst,
      votersFor,
      votersAgainst,
      voteForLoading,
      voteAgainstLoading,
      loading: ( voteForLoading || voteAgainstLoading )
    };
  }

  voteCellsForMetric( metric ) {
    const info = this.infoForMetric( metric );
    return {
      agreeCell: this.voteCell(
        metric, true, info.mostAgree, info.agreeClass, info.userVotedFor,
        info.votersFor, info.voteForLoading, info.loading ),
      disagreeCell: this.voteCell(
        metric, false, info.mostDisagree, info.disagreeClass, info.userVotedAgainst,
        info.votersAgainst, info.voteAgainstLoading, info.loading ),
      loading: info.loading
    };
  }

  render( ) {
    const observation = this.props.observation;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    const checkIcon = ( <i className="fa fa-check check" /> );
    const xIcon = ( <i className="fa fa-times check" /> );
    const hasMedia = ( observation.photos.length + observation.sounds.length ) > 0;
    const atLeastSpecies = ( observation.taxon && observation.taxon.rank_level <= 10 );
    const atLeastGenus = ( observation.taxon && observation.taxon.rank_level <= 20 );
    const mostAgree = observation.identifications_most_agree;
    const wildCells = this.voteCellsForMetric( "wild" );
    const locationCells = this.voteCellsForMetric( "location" );
    const dateCells = this.voteCellsForMetric( "date" );
    const evidenceCells = this.voteCellsForMetric( "evidence" );
    const recentCells = this.voteCellsForMetric( "recent" );
    const needsIDInfo = this.infoForMetric( "needs_id" );
    const rankText = needsIDInfo.mostDisagree ?
      I18n.t( "community_id_at_genus_level_or_lower" ) :
      I18n.t( "community_id_at_species_level_or_lower" );
    const rankPassed = needsIDInfo.mostDisagree ?
      atLeastGenus : atLeastSpecies;
    return (
      <div className="QualityMetrics">
        { this.props.tableOnly ? null : (
          <div>
            <div className="grade">
              { I18n.t( "quality_grade_" ) }:
              <span className={ `quality_grade ${observation.quality_grade} ` }>
                { _.upperFirst( I18n.t( observation.quality_grade ) ) }
              </span>
            </div>
            <div className="text">
              { I18n.t( "the_" ) } <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                containerPadding={ 20 }
                overlay={ this.popover( ) }
                className="cool"
              >
                <span>
                  { I18n.t( "data_quality_assessment_" ) }
                  <i className="fa fa-info-circle" />
                </span>
              </OverlayTrigger> { I18n.t( "is_an_evaluation" ) }
            </div>
          </div>
        ) }
        <table className="table">
          <thead>
            <tr>
              <th>{ I18n.t( "research_grade_qualification" ) }</th>
              <th className="agree">{ I18n.t( "yes" ) }</th>
              <th className="disagree">{ I18n.t( "no" ) }</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td className="metric_title">
                <i className="fa fa-calendar" />
                { I18n.t( "date_specified" ) }
              </td>
              <td className="agree">{ observation.observed_on ? checkIcon : null }</td>
              <td className="disagree">{ observation.observed_on ? null : xIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-map-marker" />
                { I18n.t( "location_specified" ) }
              </td>
              <td className="agree">{ observation.location || observation.obscured ? checkIcon : null }</td>
              <td className="disagree">{ observation.location || observation.obscured ? null : xIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-file-image-o" />
                { I18n.t( "has_photos_or_sounds" ) }
              </td>
              <td className="agree">{ hasMedia ? checkIcon : null }</td>
              <td className="disagree">{ hasMedia ? null : xIcon }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa icon-identification" />
                { I18n.t( "has_id_supported_by_two_or_more" ) }
              </td>
              <td className="agree">{ mostAgree ? checkIcon : null }</td>
              <td className="disagree">{ mostAgree ? null : xIcon }</td>
            </tr>
            <tr className={ dateCells.loading ? "disabled" : "" }>
              <td className="metric_title">
                <i className="fa fa-calendar-check-o" />
                { I18n.t( "date_is_accurate" ) }
              </td>
              <td className="agree">{ dateCells.agreeCell }</td>
              <td className="disagree">{ dateCells.disagreeCell }</td>
            </tr>
            <tr className={ locationCells.loading ? "disabled" : "" }>
              <td className="metric_title">
                <i className="fa fa-bullseye" />
                { I18n.t( "location_is_accurate" ) }
              </td>
              <td className="agree">{ locationCells.agreeCell }</td>
              <td className="disagree">{ locationCells.disagreeCell }</td>
            </tr>
            <tr className={ wildCells.loading ? "disabled" : "" }>
              <td className="metric_title">
                <i className="fa icon-icn-wild" />
                { I18n.t( "organism_is_wild" ) }
              </td>
              <td className="agree">{ wildCells.agreeCell }</td>
              <td className="disagree">{ wildCells.disagreeCell }</td>
            </tr>
            <tr className={ evidenceCells.loading ? "disabled" : "" }>
              <td className="metric_title">
                <i className="fa icon-icn-dna" />
                { I18n.t( "evidence_of_organism" ) }
              </td>
              <td className="agree">{ evidenceCells.agreeCell }</td>
              <td className="disagree">{ evidenceCells.disagreeCell }</td>
            </tr>
            <tr className={ recentCells.loading ? "disabled" : "" }>
              <td className="metric_title">
                <i className="fa fa-clock-o" />
                { I18n.t( "recent_evidence_of_organism" ) }
              </td>
              <td className="agree">{ recentCells.agreeCell }</td>
              <td className="disagree">{ recentCells.disagreeCell }</td>
            </tr>
            <tr>
              <td className="metric_title">
                <i className="fa fa-leaf" />
                { rankText }
              </td>
              <td className="agree">{ rankPassed ? checkIcon : null }</td>
              <td className="disagree">{ rankPassed ? null : xIcon }</td>
            </tr>
            { this.needsIDRow( ) }
          </tbody>
        </table>
        <FlagAnItemContainer
          item={ observation }
          itemTypeLabel={ I18n.t( "observation" ) }
          manageFlagsPath={ `/observations/${observation.id}/flags` }
        />
      </div>
    );
  }
}

QualityMetrics.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  qualityMetrics: PropTypes.object,
  voteMetric: PropTypes.func,
  unvoteMetric: PropTypes.func,
  setFlaggingModalState: PropTypes.func,
  tableOnly: PropTypes.bool
};

export default QualityMetrics;
