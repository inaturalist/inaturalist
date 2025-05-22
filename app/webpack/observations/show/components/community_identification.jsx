import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Popover, OverlayTrigger } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import CommunityIDPopover from "./community_id_popover";
import TaxonSummaryPopover from "./taxon_summary_popover";
import ConservationStatusBadge from "./conservation_status_badge";
import EstablishmentMeansBadge from "./establishment_means_badge";
import util from "../util";

class CommunityIdentification extends React.Component {
  constructor( props ) {
    super( props );
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
    this.observerOptedOut = observation.user
      && observation.user.preferences
      && observation.user.preferences.prefers_community_taxa === false;
    this.observationOptedIn = ( observation.preferences
      && observation.preferences.prefers_community_taxon === true );
    this.observationOptedOut = ( observation.preferences
      && observation.preferences.prefers_community_taxon === false );
    this.userIsObserver = config.currentUser
      && observation.user
      && config.currentUser.id === observation.user.id;
    this.communityIDIsRejected = ( this.observationOptedOut
      || ( this.observerOptedOut && !this.observationOptedIn ) );
  }

  communityIDOptIn( e ) {
    e.preventDefault( );
    const { updateObservation } = this.props;
    updateObservation( { prefers_community_taxon: true } );
  }

  communityIDOptOut( e ) {
    e.preventDefault( );
    const { updateObservation } = this.props;
    updateObservation( { prefers_community_taxon: false } );
    this.optOutPopoverClose( );
  }

  optOutPopoverClose( ) {
    this.refs["popover-trigger"].hide( );
  }

  communityIDOverridePanel( ) {
    // We're not including the owner ID requirement here b/c if you want to
    // opt-in to the CID, that shouldn't require an opinion of your own, e.g.
    // you opted out, withdrew your ID, and now you want to cede to the
    // community again
    if ( !(
      this.userIsObserver
      && this.communityIDIsRejected
    ) ) {
      return ( <div /> );
    }
    return (
      <div className="override out">
        <span className="bold">
          { I18n.t( "views.observations.community_id.you_have_opted_out" ) }
          .
        </span>
        <button
          type="button"
          className="btn btn-nostyle linky"
          href="#"
          onClick={this.communityIDOptIn}
        >
          { I18n.t( "views.observations.community_id.opt_in_for_this_observation" ) }
        </button>
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
      statement = (
        <div className="opted_out stacked">
          { I18n.t( "user_has_opted_out_of_community_id" ) }
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            overlay={(
              <Popover
                className="CommunityIDInfoOverlay"
                id="popover-community-id-info"
              >
                <div
                  dangerouslySetInnerHTML={{
                    __html: I18n.t( "views.observations.community_id.explanation" )
                  }}
                />
              </Popover>
            )}
            containerPadding={20}
          >
            <i className="fa fa-question-circle" />
          </OverlayTrigger>
        </div>
      );
    }
    return statement;
  }

  optOutPopover( ) {
    const { observation } = this.props;
    // must be observer, IDer, must not have opted out already
    if ( !(
      this.userIsObserver
      // The observer must have an ID b/c we don't want people rejecting the CID
      // to make the obs not associated with *any* taxon. If you want to reject
      // it, you need to have an opinion.
      && this.ownerID
      && observation.taxon
      && !this.observationOptedOut
    ) ) {
      return null;
    }
    // the taxa must be different, or the user defaults to opt-out, but opted in here
    if (
      this.ownerID.taxon.id === observation.taxon.id
      && !( this.observerOptedOut && this.observationOptedIn )
    ) {
      return null;
    }
    let dissimilarMessage;
    const idName = this.ownerID.taxon.preferred_common_name || this.ownerID.taxon.name;
    if ( this.ownerID.taxon.id !== observation.taxon.id ) {
      dissimilarMessage = (
        <span
          className="something"
          dangerouslySetInnerHTML={{
            __html: I18n.t( "views.observations.community_id.your_id_does_not_match", {
              taxon_name: idName
            } )
          }}
        />
      );
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
            type="button"
            className="btn btn-default reject"
            onClick={this.communityIDOptOut}
          >
            { I18n.t( "yes_reject_it" ) }
          </button>
          <button
            type="button"
            className="btn btn-nostyle cancel linky"
            onClick={this.optOutPopoverClose}
          >
            { I18n.t( "cancel" ) }
          </button>
        </div>
      </Popover>
    );
    return (
      <OverlayTrigger
        trigger="click"
        rootClose
        placement="top"
        containerPadding={20}
        overlay={popover}
        ref="popover-trigger"
      >
        <button
          type="button"
          className="btn btn-nostyle linky"
        >
          { I18n.t( "reject?" ) }
        </button>
      </OverlayTrigger>
    );
  }

  showCommunityIDModal( ) {
    const { setCommunityIDModalState } = this.props;
    setCommunityIDModalState( { show: true } );
  }

  sortedIdents( ) {
    const { observation } = this.props;
    const currentIdents = _.filter(
      observation.identifications,
      i => ( i.current && i.taxon.is_active && !i.hidden )
    );
    const taxonCounts = _.countBy( currentIdents, i => i.taxon.id );
    // Mavericks last, then sort by counts desc
    return _.sortBy(
      currentIdents,
      i => `${i.category === "maverick" ? 1 : 0}-${taxonCounts[i.taxon.id] * -1 + 1000}`
    );
  }

  dataForTaxon( taxon ) {
    const { observation, config } = this.props;
    const loggedIn = config && config.currentUser;
    const votesFor = [];
    const votesAgainst = [];
    let userAgreedToThis;
    let canAgree = true;
    const taxonImageTag = util.taxonImage( taxon );
    const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === config.currentUser.id
    ) );
    this.ownerID = _.findLast( observation.identifications, i => (
      i.current
      && i.user
      && observation.user
      && i.user.id === observation.user.id
    ) );
    if ( currentUserID ) {
      canAgree = util.taxaDissimilar( currentUserID.taxon, taxon );
      userAgreedToThis = currentUserID.agreedTo && currentUserID.agreedTo === "communityID";
    }
    const sortedIdents = this.sortedIdents( );
    let taxonIsMaverick = false;
    if ( sortedIdents.length === 1 ) {
      votesFor.push( sortedIdents[0] );
    } else if ( observation.communityTaxon ) {
      let obsTaxonAncestry = `${observation.communityTaxon.id}`;
      if ( observation.communityTaxon.ancestry ) {
        obsTaxonAncestry = `${observation.communityTaxon.ancestry}/${observation.communityTaxon.id}`;
      }
      const obsTaxonAncestors = obsTaxonAncestry.split( "/" );
      const ancestriesMatch = ( ancestry, testAncestry = null ) => {
        const compareAncestors = testAncestry ? testAncestry.split( "/" ) : obsTaxonAncestors;
        const ancestors = ancestry.split( "/" );
        return _.isEmpty( _.difference( ancestors, compareAncestors ) );
      };
      const taxonAncestry = `${taxon.ancestry}/${taxon.id}`;
      taxonIsMaverick = (
        !ancestriesMatch( taxonAncestry ) && !ancestriesMatch( obsTaxonAncestry, taxonAncestry )
      );
      const firstIdentOfTaxon = _.filter( sortedIdents, si => (
        si.taxon.id === observation.communityTaxon.id
      ) )[0];
      _.each( sortedIdents, i => {
        const idAncestry = `${i.taxon.ancestry}/${i.taxon.id}`;
        if ( ancestriesMatch( idAncestry ) || ancestriesMatch( obsTaxonAncestry, idAncestry ) ) {
          if ( ancestriesMatch( idAncestry )
            && obsTaxonAncestry !== idAncestry
            && i.disagreement ) {
            votesAgainst.push( i );
          } else if ( firstIdentOfTaxon
            && ancestriesMatch( idAncestry )
            && obsTaxonAncestry !== idAncestry
            && i.disagreement == null
            && i.id > firstIdentOfTaxon.id ) {
            votesAgainst.push( i );
          } else if ( observation.communityTaxon.ancestry
            && !observation.communityTaxon.ancestry.split( "/" ).includes( i.taxon.id ) ) {
            votesFor.push( i );
          }
        } else if ( observation.communityTaxon.ancestry
          && !observation.communityTaxon.ancestry.split( "/" ).includes( i.taxon.id ) ) {
          votesAgainst.push( i );
        }
      } );
    }
    const totalVotes = votesFor.length + votesAgainst.length;
    const voteCells = [];
    const width = `${_.round( 100 / totalVotes, 3 )}%`;
    let taxaSeen = [];
    _.each( votesFor, v => {
      if ( taxaSeen.indexOf( v.taxon.id ) < 0 ) {
        taxaSeen.push( v.taxon.id );
      }
      const voteCellClassName = `for taxon-${taxaSeen.indexOf( v.taxon.id )} ${taxon.id === v.taxon.id ? "exact" : "not-exact"}`;
      voteCells.push( (
        <CommunityIDPopover
          className={taxon.id === v.taxon.id ? "exact" : "not-exact"}
          key={`community-id-${v.id}`}
          keyPrefix="ids"
          identification={v}
          communityIDTaxon={observation.communityTaxon}
          agreement
          style={{ width }}
          contents={( <div className={voteCellClassName} /> )}
        />
      ) );
    } );
    taxaSeen = [];
    _.each( votesAgainst, v => {
      if ( taxaSeen.indexOf( v.taxon.id ) < 0 ) {
        taxaSeen.push( v.taxon.id );
      }
      const voteCellClassName = `against taxon-${taxaSeen.indexOf( v.taxon.id )} ${taxon.id === v.taxon.id ? "exact" : "not-exact"}`;
      voteCells.push( (
        <CommunityIDPopover
          className={taxon.id === v.taxon.id ? "exact" : "not-exact"}
          key={`community-id-${v.id}`}
          keyPrefix="ids"
          identification={v}
          communityID={observation.communityTaxon}
          agreement={false}
          style={{ width }}
          contents={( <div className={voteCellClassName} /> )}
        />
      ) );
    } );
    let lines;
    let numbers;
    if ( voteCells.length > 1 ) {
      lines = (
        <div className="lines">
          <div className="two-thirds">&nbsp;</div>
        </div>
      );
      numbers = (
        <div className="numbers">
          <div className="first">0</div>
          <div className="two-thirds">{ I18n.t( "two_thirds" ) }</div>
          <div className="last">{ voteCells.length }</div>
        </div>
      );
    }
    const stats = (
      <span>
        <span className="cumulative">
          { voteCells.length > 1
            ? I18n.t( "cumulative_ids", { count: votesFor.length, total: voteCells.length } ) : "" }
        </span>
        <div className="graphic">
          <div className="vote-cells">
            { voteCells }
          </div>
          { lines }
          { numbers }
        </div>
      </span>
    );
    const photo = (
      <TaxonSummaryPopover
        taxon={taxon}
        contents={taxonImageTag}
      />
    );
    return {
      taxon,
      stats,
      photo,
      canAgree,
      userAgreedToThis,
      taxonIsMaverick,
      sortedIdents,
      votesFor
    };
  }

  render( ) {
    const {
      observation, config, addID, onClickCompare, performOrOpenConfirmationModal
    } = this.props;
    const loggedIn = config && config.currentUser;
    const { communityTaxon } = observation;
    if ( !observation || !observation.user ) {
      return ( <div /> );
    }
    this.setInstanceVars( );
    let canAgree = true;
    let userAgreedToThis;
    let stats;
    let photo;
    const taxonImageTag = util.taxonImage( communityTaxon );
    if ( communityTaxon ) {
      (
        {
          stats,
          photo,
          canAgree,
          userAgreedToThis
        } = this.dataForTaxon( communityTaxon )
      );
    } else {
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
    const agreeButton = loggedIn
      ? (
        <button
          type="button"
          className="btn btn-default"
          disabled={!canAgree}
          onClick={( ) => {
            performOrOpenConfirmationModal( ( ) => {
              addID( communityTaxon, { agreedTo: "communityID" } );
            } );
          }}
        >
          {
            userAgreedToThis
              ? <div className="loading_spinner" />
              : <i className="fa fa-check" />
          }
          { " " }
          { I18n.t( "agree_" ) }
        </button>
      ) : (
        <a href="/login">
          <button
            type="button"
            className="btn btn-default"
          >
            <i className="fa fa-check" />
            { I18n.t( "agree_" ) }
          </button>
        </a>
      );

    return (
      <div className="CommunityIdentification collapsible-section">
        <h4>
          { I18n.t( "community_id_heading" ) }
          <span className="header-actions pull-right">
            { this.optOutPopover( ) }
            { loggedIn && !observation.communityTaxon && (
              <button
                type="button"
                className="linky compare-link"
                onClick={e => {
                  if ( onClickCompare ) {
                    return onClickCompare( e, observation.taxon, observation );
                  }
                  return true;
                }}
              >
                { I18n.t( "compare" ) }
              </button>
            ) }
            <button
              type="button"
              className="btn btn-nostyle linky"
              onClick={this.showCommunityIDModal}
            >
              { I18n.t( "whats_this?" ) }
            </button>
          </span>
        </h4>
        { this.communityIDOverrideStatement( ) }
        { this.communityIDOverridePanel( ) }
        { communityTaxon ? (
          <div className="info">
            <div className="photo">{ photo }</div>
            <div className="badges">
              <ConservationStatusBadge taxon={communityTaxon} />
              <EstablishmentMeansBadge taxon={communityTaxon} />
            </div>
            <SplitTaxon
              taxon={communityTaxon}
              url={communityTaxon ? `/taxa/${communityTaxon.id}` : null}
              user={config.currentUser}
            />
            { stats }
          </div>
        ) : (
          <div className="info">
            <div className="about">
              {I18n.t( "the_community_id_requires_at_least_two_identifications" )}
            </div>
          </div>
        ) }
        { communityTaxon && (
          <div className="action">
            <div className="btn-space">
              { agreeButton }
            </div>
            { loggedIn ? (
              <div className="btn-space">
                <button
                  type="button"
                  className="btn btn-default"
                  onClick={e => {
                    if ( onClickCompare ) {
                      return onClickCompare( e, communityTaxon, observation );
                    }
                    return true;
                  }}
                >
                  <i className="fa fa-exchange" />
                  { " " }
                  { I18n.t( "compare" ) }
                </button>
              </div>
            ) : null }
            <div className="btn-space">
              <button
                type="button"
                className="btn btn-default"
                onClick={this.showCommunityIDModal}
              >
                <i className="fa fa-info-circle" />
                { " " }
                { I18n.t( "about" ) }
              </button>
            </div>
          </div>
        ) }
      </div>
    );
  }
}

CommunityIdentification.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addID: PropTypes.func,
  setCommunityIDModalState: PropTypes.func,
  updateObservation: PropTypes.func,
  onClickCompare: PropTypes.func,
  performOrOpenConfirmationModal: PropTypes.func
};

CommunityIdentification.defaultProps = {
  config: {}
};

export default CommunityIdentification;
