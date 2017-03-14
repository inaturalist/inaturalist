import _ from "lodash";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";
import CommunityIDPopover from "./community_id_popover";
import util from "../util";

const CommunityIdentification = ( { observation, config, addID } ) => {
  const loggedIn = config && config.currentUser;
  const taxon = observation.taxon;
  if ( !observation || !taxon ) {
    return ( <div /> );
  }
  const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
    i.current && i.user && i.user.id === config.currentUser.id
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
  return (
    <div className="CommunityIdentification">
      <h4>Community ID</h4>
      <div className="info">
        <div className="photo">
          <a href={ `/taxa/${taxon.id}` }>
            { taxonImageTag }
          </a>
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
          <a href={ `/taxa/${taxon.id}` }>
            <button className="btn btn-default">
              <i className="fa fa-info-circle" /> About
            </button>
          </a>
        </div>
      </div>
    </div>
  );
};

CommunityIdentification.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  addID: PropTypes.func
};

export default CommunityIdentification;
