import moment from "moment";
import React from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";

const Inativersary = ( {
  config,
  date: dateProp,
  text: textProp,
  uniqueKey,
  user
} ) => {
  const joinDate = moment( user.created_at );
  // default to now. Note that moment yields different results when parsing
  // null, NaN, false, etc
  const date = dateProp ? moment( dateProp ) : moment( );
  const isInativersary = (
    joinDate.month( ) === date.month( )
    && joinDate.date( ) === date.date( )
    // Not an anniversary if you signed up on the same day
    && joinDate.year( ) !== date.year( )
  );
  if ( !isInativersary ) return null;
  const loggedInUser = ( config && config.currentUser ) ? config.currentUser : null;
  const viewerIsAdmin = loggedInUser && loggedInUser.roles
    && loggedInUser.roles.indexOf( "admin" ) >= 0;
  // Just testing with staff for now
  if ( !viewerIsAdmin ) return null;

  // Text is obs-specific, so might be better to only show if an obs-specific
  // prop is present. Text also needs to be globalized with plurals, of course.
  const text = dateProp
    ? ( `
      ${user.name || user.login} observed this on their iNativersary, exactly
      ${date.year() - joinDate.year()} years after they joined iNat!
    ` )
    : ( `
      It's ${user.name || user.login}'s iNativersary!
      As of today they've been on iNat for ${date.year() - joinDate.year()} years!
    ` );

  return (
    <OverlayTrigger
      trigger="click"
      rootClose
      placement="bottom"
      containerPadding={20}
      overlay={(
        <Popover
          className="InativersaryOverlay"
          id={`popover-inativersary-${uniqueKey}`}
        >
          <div className="contents">
            <img src="/assets/walrus.svg" alt="iNativersary" className="inativersary" />
            <div>
              { text }
              &nbsp;
              <span>Why is there a walrus? Reasons.</span>
            </div>
          </div>
        </Popover>
      )}
    >
      {/*
        <button type="button" className="btn btn-nostyle btn-inativersary">
          <img src="/assets/walrus.svg" alt="iNativersary" className="inativersary" />
        </button>
      */}
      <button type="button" className="btn btn-nostyle btn-inativersary" aria-label="iNativersary">
        <i className="fa fa-birthday-cake" />
      </button>
    </OverlayTrigger>
  );
};

Inativersary.propTypes = {
  config: PropTypes.object,
  date: PropTypes.string,
  text: PropTypes.string,
  uniqueKey: PropTypes.string,
  user: PropTypes.object
};

export default Inativersary;
