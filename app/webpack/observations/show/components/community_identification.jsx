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
    this.setInstanceVars = this.setInstanceVars.bind( this );
    this.communityIDOptIn = this.communityIDOptIn.bind( this );
    this.communityIDOptOut = this.communityIDOptOut.bind( this );
    this.showCommunityIDModal = this.showCommunityIDModal.bind( this );
    this.communityIDOverridePanel = this.communityIDOverridePanel.bind( this );
    this.communityIDOverrideStatement = this.communityIDOverrideStatement.bind( this );
    this.optOutPopoverClose = this.optOutPopoverClose.bind( this );
  }

  setInstanceVars( ) {
    const { observation, config } = this.props;
    this.loggedIn = config && config.currentUser;
    this.observerOptedOut = ( observation.user.preferences &&
      observation.user.preferences.prefers_community_taxa === false );
    this.observationOptedIn = ( observation.preferences &&
      observation.preferences.prefers_community_taxon === true );
    this.observationOptedOut = ( observation.preferences &&
      observation.preferences.prefers_community_taxon === false );
    this.userIsObserver = this.loggedIn && config.currentUser.id === observation.user.id;
    this.communityIDIsRejected = ( this.observationOptedOut ||
      ( this.observerOptedOut && !this.observationOptedIn ) );
  }

  communityIDOptIn( e ) {
    e.preventDefault( );
    this.props.updateObservation( { prefers_community_taxon: true } );
  }

  communityIDOptOut( e ) {
    e.preventDefault( );
    this.props.updateObservation( { prefers_community_taxon: false } );
    this.optOutPopoverClose( );
  }

  optOutPopoverClose( ) {
    this.refs["popover-trigger"].hide( );
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
    if ( !( this.userIsObserver && this.ownerID && this.communityIDIsRejected ) ) {
      return ( <div /> );
    }
    return (
      <div className="override out">
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
      </div>
    );
  }

  communityIDOverrideStatement( ) {
    let statement;
    if ( this.communityIDIsRejected ) {
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

  optOutPopover( ) {
    // must be observer, IDer, must not have opted out already
    if ( !( this.userIsObserver && this.ownerID && this.props.observation.taxon && !this.observationOptedOut ) ) {
      return ( <div /> );
    }
    // the taxa must be different, or the user defaults to opt-out, but opted in here
    if ( this.ownerID.taxon.id === this.props.observation.taxon.id &&
         !( this.observerOptedOut && this.observationOptedIn ) ) {
      return ( <div /> );
    }
    let dissimilarMessage;
    const idName = this.ownerID.taxon.preferred_common_name || this.ownerID.taxon.name;
    if ( this.ownerID.taxon.id !== this.props.observation.taxon.id ) {
      dissimilarMessage = ( <span className="something" dangerouslySetInnerHTML={ { __html:
        I18n.t( "views.observations.community_id.your_id_does_not_match", {
          taxon_name: idName } ) } }
      /> );
    }
    const popover = (
      <Popover
        className="OptOutPopover"
        id="popover-opt-out"
      >
        <p>
          { I18n.t( "if_for_some_reason_a_user_doesnt_agree" ) }
        </p>
        <p>
          { dissimilarMessage }
        </p>
        <div className="action">
          <button
            className="btn btn-default reject"
            onClick={ this.communityIDOptOut }
          >
            { I18n.t( "yes_reject_it" ) }
          </button>
          <div
            className="cancel linky"
            onClick={ this.optOutPopoverClose }
          >
            { I18n.t( "cancel" ) }
          </div>
        </div>
      </Popover>
    );
    return (
      <OverlayTrigger
        trigger="click"
        rootClose
        placement="top"
        containerPadding={ 20 }
        overlay={ popover }
        ref="popover-trigger"
      >
        <div className="reject linky">
          { I18n.t( "reject?" ) }
        </div>
      </OverlayTrigger>
    );
  }

  showCommunityIDModal( ) {
    this.props.setCommunityIDModalState( { show: true } );
  }

  dataForTaxon( taxon ) {
    const { observation, config } = this.props;
    const loggedIn = config && config.currentUser;
    const votesFor = [];
    const votesAgainst = [];
    let userAgreedToThis;
    let canAgree = true;
    const taxonImageTag = util.taxonImage( taxon );
    const tid = taxon.rank_level <= 10 ? taxon.ancestor_ids[taxon.ancestor_ids - 2] : taxon.id;
    const compareLink = `/observations/identotron?observation_id=${observation.id}&taxon=${tid}`;
    const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === config.currentUser.id
    ) );
    this.ownerID = _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === observation.user.id
    ) );
    if ( currentUserID ) {
      canAgree = util.taxaDissimilar( currentUserID.taxon, taxon );
      userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo === "communityID";
    }
    const obsTaxonAncestry = observation.taxon.ancestry ? `${observation.taxon.ancestry}/${observation.taxon.id}` : `${observation.taxon.id}`;
    const taxonAncestry = `${taxon.ancestry}/${taxon.id}`;
    const taxonIsMaverick = (
      !obsTaxonAncestry.includes( taxonAncestry ) && !taxonAncestry.includes( obsTaxonAncestry )
    );
    // const sortedIdents = _.sortBy( observation.identifications, i => `${i.taxon.ancestry}/${i.taxon.id}` );
    // const sortedIdents = observation.identifications;
    const sortedIdents = _.sortBy( observation.identifications, i => i.created_at );
    _.each( sortedIdents, i => {
      if ( !i.current ) { return; }
      const idAncestry = `${i.taxon.ancestry}/${i.taxon.id}`;
      if ( obsTaxonAncestry.includes( idAncestry ) || idAncestry.includes( obsTaxonAncestry ) ) {
        votesFor.push( i );
      } else {
        votesAgainst.push( i );
      }
    } );
    const totalVotes = votesFor.length + votesAgainst.length;
    let voteCells = [];
    const width = `${_.round( 100 / totalVotes, 3 )}%`;
    let taxaSeen = [];
    _.each( votesFor, v => {
      if ( taxaSeen.indexOf( v.taxon.id ) < 0 ) {
        taxaSeen.push( v.taxon.id );
      }
      let voteCellClassName = `for taxon-${taxaSeen.indexOf( v.taxon.id )} ${taxon.id === v.taxon.id ? "exact" : "not-exact"}`;
      voteCells.push( (
        <CommunityIDPopover
          className={ taxon.id === v.taxon.id ? "exact" : "not-exact" }
          key={ `community-id-${v.id}` }
          keyPrefix="ids"
          identification={ v }
          communityIDTaxon={ observation.taxon }
          agreement
          style={ { width } }
          contents={ ( <div className={ voteCellClassName } /> ) }
        />
      ) );
    } );
    taxaSeen = [];
    _.each( votesAgainst, v => {
      if ( taxaSeen.indexOf( v.taxon.id ) < 0 ) {
        taxaSeen.push( v.taxon.id );
      }
      let voteCellClassName = `against taxon-${taxaSeen.indexOf( v.taxon.id )} ${taxon.id === v.taxon.id ? "exact" : "not-exact"}`;
      voteCells.push( (
        <CommunityIDPopover
          className={ taxon.id === v.taxon.id ? "exact" : "not-exact" }
          key={ `community-id-${v.id}` }
          keyPrefix="ids"
          identification={ v }
          communityID={ observation.taxon }
          agreement={ false }
          style={ { width } }
          contents={ ( <div className={ voteCellClassName } /> ) }
        />
      ) );
    } );
    let linesAndNumbers;
    if ( voteCells.length > 1 ) {
      linesAndNumbers = (
        <span>
          <div className="lines">
            <div className="two-thirds">&nbsp;</div>
          </div>
          <div className="numbers">
            <div className="first">0</div>
            <div className="two-thirds">{ I18n.t( "two_thirds" ) }</div>
            <div className="last">{ voteCells.length }</div>
          </div>
        </span>
      );
    }
    const stats = (
      <span>
        <span className="cumulative">
          { voteCells.length > 1 ?
            I18n.t( "cumulative_ids", { count: votesFor.length, total: voteCells.length } ) : "" }
        </span>
        <div className="graphic">
          { voteCells }
          { linesAndNumbers }
        </div>
      </span>
    );
    const photo = (
      <TaxonSummaryPopover
        taxon={ taxon }
        contents={ taxonImageTag }
      />
    );
    return {
      taxon,
      compareLink,
      stats,
      photo,
      canAgree,
      userAgreedToThis,
      taxonIsMaverick
    };
  }

  render( ) {
    const { observation, config, addID } = this.props;
    const loggedIn = config && config.currentUser;
    const taxon = observation.taxon;
    if ( !observation || !observation.user ) {
      return ( <div /> );
    }
    this.setInstanceVars( );
    let compareLink;
    let canAgree = true;
    let userAgreedToThis;
    let stats;
    let photo;
    const taxonImageTag = util.taxonImage( taxon );
    if ( taxon ) {
      ( { compareLink, stats, photo, canAgree, userAgreedToThis } = this.dataForTaxon( taxon ) );
    } else {
      compareLink = `/observations/identotron?observation_id=${observation.id}&taxon=0`;
      canAgree = false;
      stats = (
        <span>
          <span className="cumulative">
            { I18n.t( "no_ids_have_been_suggested_yet" ) }
          </span>
        </span>
      );
      photo = taxonImageTag;
    }
    const agreeButton = loggedIn ?
      (
        <button className="btn btn-default" disabled={ !canAgree }
          onClick={ ( ) => { addID( taxon, { agreedTo: "communityID" } ); } }
        >
        { userAgreedToThis ? ( <div className="loading_spinner" /> ) :
          ( <i className="fa fa-check" /> ) } { I18n.t( "agree_" ) }
        </button>
      ) : (
        <a href="/login">
          <button className="btn btn-default">
            <i className="fa fa-check" />
            { I18n.t( "agree_" ) }
          </button>
        </a>
      );
    const test = $.deparam.querystring().test;
    const proposedTaxa = {};
    const proposedTaxonItems = [];
    const currentIdents = _.filter( observation.identifications, i => i.current );
    if ( currentIdents.length > 1 ) {
      for ( let i = 0; i < currentIdents.length; i++ ) {
        const ident = currentIdents[i];
        if ( !proposedTaxa[ident.taxon.id] ) {
          proposedTaxonItems.push( this.dataForTaxon( ident.taxon ) );
          proposedTaxa[ident.taxon.id] = ident.taxon.id;
        }
      }
    }
    const numIdentifiers = currentIdents.length;

    let visualization;
    if ( test === "cid-vis3" || test === "cid-vis4" ) {
      visualization = (
        <div className="cid-extended">
          <div className="info">
            <div className="about stacked">
              Over 2/3 of <strong>{ numIdentifiers } people</strong> agree it is:
              <a href={ compareLink } className="pull-right compare-link">
                <i className="fa fa-exchange" /> { I18n.t( "compare" ) }
              </a>
            </div>
            <div className="inner">
              <div className="photo">{ photo }</div>
              <div className="stats-and-name">
                <div className="badges">
                  <ConservationStatusBadge observation={ observation } />
                  <EstablishmentMeansBadge observation={ observation } />
                </div>
                <SplitTaxon
                  taxon={ taxon }
                  url={ taxon ? `/taxa/${taxon.id}` : null }
                  placeholder={ observation.species_guess }
                />
                { stats }
              </div>
            </div>
          </div>
          <div className="proposed-taxa">
            { _.map( proposedTaxonItems, proposedTaxonData => (
              <div className="info">
                { proposedTaxonData.taxonIsMaverick ? (
                  <div className="about stacked maverick">
                    <i className="fa fa-bolt" /> { I18n.t( "maverick" ) } Suggestion:
                  </div>
                ) : null }
                <div className="inner">
                  <div className="photo">{ proposedTaxonData.photo }</div>
                  <div className="stats-and-name">
                    <SplitTaxon
                      taxon={ proposedTaxonData.taxon }
                      url={ proposedTaxonData.taxon ? `/taxa/${proposedTaxonData.taxon.id}` : null }
                    />
                    { proposedTaxonData.stats }
                  </div>
                </div>
              </div>
            ) ) }
          </div>
        </div>
      );
    } else {
      visualization = (
        <div className="info">
          <div className="photo">{ photo }</div>
          <div className="badges">
            <ConservationStatusBadge observation={ observation } />
            <EstablishmentMeansBadge observation={ observation } />
          </div>
          <SplitTaxon
            taxon={ taxon }
            url={ taxon ? `/taxa/${taxon.id}` : null }
            placeholder={ observation.species_guess }
          />
          { stats }
        </div>
      );
    }

    return (
      <div className={ `CommunityIdentification ${test}` }>
        <h4>
          { I18n.t( "community_id_heading" ) }
          { this.communityIDOverrideStatement( ) }
          { this.optOutPopover( ) }
        </h4>
        { this.communityIDOverridePanel( ) }
        { visualization }
        <div className="action">
          <div className="btn-space">
            { agreeButton }
          </div>
          <div className="btn-space">
            <a href={ compareLink }>
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
