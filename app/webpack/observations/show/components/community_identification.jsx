import _ from "lodash";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";
import CommunityIDPopover from "./community_id_popover";

const CommunityIdentification = ( { observation, config } ) => {
  const loggedIn = config && config.currentUser;
  const taxon = observation.taxon;
  if ( !observation || !taxon ) {
    return ( <div /> );
  }
  const currentUserID = loggedIn && _.findLast( observation.identifications, i => (
    i.current && i.user && i.user.id === config.currentUser.id
  ) );
  let taxonImageTag;
  if ( taxon.defaultPhoto ) {
    taxonImageTag = (
      <img src={ taxon.defaultPhoto.photoUrl( ) } className="taxon-image" />
    );
  } else if ( taxon.iconic_taxon_name ) {
    taxonImageTag = (
      <i
        className={`taxon-image icon icon-iconic-${
          taxon.iconic_taxon_name.toLowerCase( )}`}
      >
      </i>
    );
  } else {
    taxonImageTag = <i className="taxon-image icon icon-iconic-unknown"></i>;
  }
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
        keyPrefix="ids"
        identification={ v }
        communityIDTaxon={ observation.taxon }
        agreement
        contents={ ( <div className="for" style={ { width } } /> ) }
      />
    ) );
  } );
  _.each( votesAgainst, v => {
    voteCells.push( (
      <CommunityIDPopover
        keyPrefix="ids"
        identification={ v }
        communityID={ observation.taxon }
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
          { taxonImageTag }
        </div>
        <SplitTaxon taxon={observation.taxon} url={`/taxa/${observation.taxon.id}`} />
        <span className="cumulative">
          Cumulative IDs: { voteCells.length }
        </span>
        <div className="graphic">
          { voteCells }
        </div>
      </div>
      <div className="action">
        <div className="btn-space">
          <button className="btn btn-default">
            <i className="fa fa-check" /> Agree
          </button>
        </div>
        <div className="btn-space">
          <a href={ `/observations/identotron?observation_id=${observation.id}&taxon_id=${observation.taxon.id}` }>
            <button className="btn btn-default">
              <i className="fa fa-exchange" /> Compare
            </button>
          </a>
        </div>
        <div className="btn-space">
          <button className="btn btn-default">
            <i className="fa fa-info-circle" /> About
          </button>
        </div>
      </div>
    </div>
  );
};

CommunityIdentification.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object
};

export default CommunityIdentification;
