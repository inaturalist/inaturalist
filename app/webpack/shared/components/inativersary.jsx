import moment from "moment";
import React from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";

const Inativersary = ( { uniqueKey, user } ) => {
  const joinDate = moment( user.created_at );
  const now = moment( );
  const isInativersary = ( joinDate.month() === now.month() && joinDate.day() === now.day() );
  if ( !isInativersary ) return null;
  if ( !window.location.search.match( /test=inativersary/ ) ) return null;

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
              { `It's ${user.name || user.login}'s iNativersary!` }
              &nbsp;
              { `As of today they've been on iNat for ${now.year() - joinDate.year()} years!` }
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
  uniqueKey: PropTypes.string,
  user: PropTypes.object
};

export default Inativersary;
