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
    this.communityIDOptIn = this.communityIDOptIn.bind( this );
    this.communityIDOptOut = this.communityIDOptOut.bind( this );
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
    const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === config.currentUser.id
    ) );
    const ownerID = _.findLast( observation.identifications, i => (
      i.current && i.user && i.user.id === observation.user.id
    ) );
    let canAgree = true;
    if ( currentUserID ) {
      canAgree = util.taxaDissimilar( currentUserID.taxon, taxon );
    }
    const taxonImageTag = util.taxonImage( taxon );
    const votesFor = [];
    const votesAgainst = [];
    const taxonAncestry = `${taxon.ancestry}/${taxon.id}`;
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
    const width = `${Math.floor( 100 / totalVotes )}%`;
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
    let communityOverridePanel;
    if ( ownerID && observation.user.preferences.prefers_community_taxa === false ) {
      if ( !observation.preferences.prefers_community_taxon ) {
        communityOverridePanel = ( <div className="override out">
          <span className="bold">
            You have opted out of community identifications.
          </span>
          <a href="#" onClick={ this.communityIDOptIn }>
            Opt in for this observation
          </a>
          <span className="separator">·</span>
          <a href="/users/edit">
            Edit your default settings
          </a>
        </div> );
      } else {
        let dissimilarMessage;
        const idName = ownerID.taxon.preferred_common_name || ownerID.taxon.name;
        if ( util.taxaDissimilar( ownerID.taxon, taxon ) ) {
          dissimilarMessage = ( <span className="something">
            Your ID (<span className="bold">{ idName }</span>) does not match
            the community ID.&nbsp;
          </span> );
        }
        const popover = (
          <Popover
            className="CommunityIDInfoOverlay"
            id="popover-community-id-info"
          >
            <p>
              If for some reason a user doesn't agree with the community taxon,
              they can reject it, which means their ID is the one used for
              linking to other observations, updating life lists, etc. It also
              means their observation can only become research grade when the
              community agrees with them.
            </p>
            <p>
              However, the community ID is still shown, so all may see the
              different IDs that have been suggested.
            </p>
          </Popover>
        );
        communityOverridePanel = ( <div className="override in">
          { dissimilarMessage }
          Would you like to <a href="#" onClick={ this.communityIDOptOut }>
            reject the community ID
          </a>?
          <OverlayTrigger
            trigger="click"
            rootClose
            placement="top"
            overlay={popover}
          >
            <i className="fa fa-info-circle" />
          </OverlayTrigger>
        </div> );
      }
    }
    return (
      <div className="CommunityIdentification">
        <h4>Community ID</h4>
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
            Cumulative IDs: { voteCells.length }
          </span>
          <div className="graphic">
            { voteCells }
          </div>
        </div>
        <div className="action">
          <div className="btn-space">
            <button className="btn btn-default" disabled={ !canAgree }
              onClick={ ( ) => { addID( taxon ); } }
            >
              <i className="fa fa-check" /> Agree
            </button>
          </div>
          <div className="btn-space">
            <a href={ `/observations/identotron?observation_id=${observation.id}&taxon_id=${taxon.id}` }>
              <button className="btn btn-default">
                <i className="fa fa-exchange" /> Compare
              </button>
            </a>
          </div>
          <div className="btn-space">
            <button className="btn btn-default" onClick={ this.showCommunityIDModal }>
              <i className="fa fa-info-circle" /> About
            </button>
          </div>
        </div>
        { communityOverridePanel }
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
