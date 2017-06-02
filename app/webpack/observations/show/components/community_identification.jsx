import _ from "lodash";
import React, { PropTypes } from "react";
import { Popover, OverlayTrigger } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import CommunityIDPopover from "./community_id_popover";
import TaxonSummaryPopover from "./taxon_summary_popover";
import ConservationStatusBadge from "../components/conservation_status_badge";
import EstablishmentMeansBadge from "../components/establishment_means_badge";
import util from "../util";

class CommunityIdentification extends React.Component {

  constructor( ) {
    super( );
    this.ownerID = null;
    this.communityIDOptIn = this.communityIDOptIn.bind( this );
    this.communityIDOptOut = this.communityIDOptOut.bind( this );
    this.communityIDOverridePanel = this.communityIDOverridePanel.bind( this );
    this.communityIDOverrideStatement = this.communityIDOverrideStatement.bind( this );
    this.showCommunityIDModal = this.showCommunityIDModal.bind( this );
  }

  communityIDOptIn( e ) {
    e.preventDefault( );
    this.props.updateObservation( { prefers_community_taxon: true } );
  }

  communityIDOptOut( e ) {
    e.preventDefault( );
    this.props.updateObservation( { prefers_community_taxon: false } );
  }

  communityIDInfoPopover( ) {
    return (
      <Popover
        className="CommunityIDInfoOverlay"
        id="popover-community-id-info"
      >
        <div dangerouslySetInnerHTML={ { __html:
          I18n.t( "views.observations.community_id.explanation" ) } }
        />
      </Popover>
    );
  }

  communityIDOverridePanel( ) {
    const { observation, config } = this.props;
    const loggedIn = config && config.currentUser;
    const observerOptedOut = ( observation.user.preferences &&
      observation.user.preferences.prefers_community_taxa === false );
    const observationOptedOut = ( observation.preferences &&
      observation.preferences.prefers_community_taxon === false );
    let panel;
    if ( this.ownerID && ( observerOptedOut || observationOptedOut ) &&
         loggedIn && config.currentUser.id === observation.user.id ) {
      if ( observationOptedOut ) {
        panel = ( <div className="override out">
          <span className="bold">
            { I18n.t( "views.observations.community_id.you_have_opted_out" ) }.
          </span>
          <a href="#" onClick={ this.communityIDOptIn }>
            { I18n.t( "views.observations.community_id.opt_in_for_this_observation" ) }
          </a>
          <span className="separator">·</span>
          <a href="/users/edit">
            { I18n.t( "edit_your_default_settings" ) }
          </a>
        </div> );
      } else {
        let dissimilarMessage;
        const idName = this.ownerID.taxon.preferred_common_name || this.ownerID.taxon.name;
        if ( util.taxaDissimilar( this.ownerID.taxon, this.props.observation.taxon ) ) {
          dissimilarMessage = ( <span className="something" dangerouslySetInnerHTML={ { __html:
            I18n.t( "views.observations.community_id.your_id_does_not_match", {
              taxon_name: idName } ) } }
          /> );
        }
        panel = ( <div className="override in">
          { dissimilarMessage }
          { I18n.t( "would_you_like_to" ) } <a href="#" onClick={ this.communityIDOptOut }>
            { I18n.t( "reject_the_community_id" ) }
          </a>?
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            containerPadding={ 20 }
            overlay={ this.communityIDInfoPopover( ) }
          >
            <i className="fa fa-info-circle" />
          </OverlayTrigger>
        </div> );
      }
    }
    return panel;
  }

  communityIDOverrideStatement( ) {
    const observation = this.props.observation;
    let statement;
    if ( observation.preferences.prefers_community_taxon === false ) {
      statement = ( <span className="opted_out">
        ({ I18n.t( "user_has_opted_out_of_community_id" ) })
        <OverlayTrigger
          trigger="click"
          rootClose
          placement="top"
          overlay={ this.communityIDInfoPopover( ) }
          containerPadding={ 20 }
        >
          <i className="fa fa-info-circle" />
        </OverlayTrigger>
      </span> );
    }
    return statement;
  }
  showCommunityIDModal( ) {
    this.props.setCommunityIDModalState( { show: true } );
  }

  render( ) {
    const { observation, config, addID } = this.props;
    const loggedIn = config && config.currentUser;
    const taxon = observation.taxon;
    if ( !observation || !taxon ) {
      return ( <div /> );
    }
    const compareTaxonID = taxon.rank_level <= 10 ?
      taxon.ancestor_ids[taxon.ancestor_ids - 2] : taxon.id;
    const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === config.currentUser.id
    ) );
    this.ownerID = _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === observation.user.id
    ) );
    let canAgree = true;
    let userAgreedToThis;
    if ( currentUserID ) {
      canAgree = util.taxaDissimilar( currentUserID.taxon, taxon );
      userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo === "communityID";
    }
    const taxonImageTag = util.taxonImage( taxon );
    const votesFor = [];
    const votesAgainst = [];
    const taxonAncestry = taxon.ancestry ? `${taxon.ancestry}/${taxon.id}` : `${taxon.id}`;
    _.each( observation.identifications, i => {
      if ( !i.current ) { return; }
      const idAncestry = `${i.taxon.ancestry}/${i.taxon.id}`;
      if ( taxonAncestry.includes( idAncestry ) || idAncestry.includes( taxonAncestry ) ) {
        votesFor.push( i );
      } else {
        votesAgainst.push( i );
      }
    } );
    const totalVotes = votesFor.length + votesAgainst.length;
    const voteCells = [];
    const width = `${_.round( 100 / totalVotes, 3 )}%`;
    _.each( votesFor, v => {
      voteCells.push( (
        <CommunityIDPopover
          key={ `community-id-${v.id}` }
          keyPrefix="ids"
          identification={ v }
          communityIDTaxon={ taxon }
          agreement
          contents={ ( <div className="for" style={ { width } } /> ) }
        />
      ) );
    } );
    _.each( votesAgainst, v => {
      voteCells.push( (
        <CommunityIDPopover
          key={ `community-id-${v.id}` }
          keyPrefix="ids"
          identification={ v }
          communityID={ taxon }
          agreement={ false }
          contents={ ( <div className="against" style={ { width } } /> ) }
        />
      ) );
    } );

    return (
      <div className="CommunityIdentification">
        <h4>
          { I18n.t( "community_id_heading" ) }
          { this.communityIDOverrideStatement( ) }
        </h4>
        <div className="info">
          <div className="photo">
            <TaxonSummaryPopover
              taxon={ taxon }
              contents={ taxonImageTag }
            />
          </div>
          <div className="badges">
            <ConservationStatusBadge observation={ observation } />
            <EstablishmentMeansBadge observation={ observation } />
          </div>
          <SplitTaxon taxon={observation.taxon} url={`/taxa/${taxon.id}`} />
          <span className="cumulative">
            { I18n.t( "cumulative_ids", { count: votesFor.length, total: voteCells.length } ) }
          </span>
          <div className="graphic">
            { voteCells }
            <div className="lines">
              <div className="two-thirds">&nbsp;</div>
            </div>
            <div className="numbers">
              <div className="first">1</div>
              <div className="two-thirds">{ I18n.t( "two_thirds" ) }</div>
              <div className="last">{ voteCells.length }</div>
            </div>
          </div>
        </div>
        <div className="action">
          <div className="btn-space">
            <button className="btn btn-default" disabled={ !canAgree }
              onClick={ ( ) => { addID( taxon, { agreedTo: "communityID" } ); } }
            >
            { userAgreedToThis ? ( <div className="loading_spinner" /> ) :
              ( <i className="fa fa-check" /> ) } { I18n.t( "agree_" ) }
            </button>
          </div>
          <div className="btn-space">
            <a href={
              `/observations/identotron?observation_id=${observation.id}&taxon=${compareTaxonID}` }
            >
              <button className="btn btn-default">
                <i className="fa fa-exchange" /> { I18n.t( "compare" ) }
              </button>
            </a>
          </div>
          <div className="btn-space">
            <button className="btn btn-default" onClick={ this.showCommunityIDModal }>
              <i className="fa fa-info-circle" /> { I18n.t( "about" ) }
            </button>
          </div>
        </div>
        { this.communityIDOverridePanel( ) }
      </div>
    );
  }
}

CommunityIdentification.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addID: PropTypes.func,
  setCommunityIDModalState: PropTypes.func,
  updateObservation: PropTypes.func
};

export default CommunityIdentification;
