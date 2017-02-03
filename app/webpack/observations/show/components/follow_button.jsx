import React, { PropTypes } from "react";
import { Dropdown, MenuItem } from "react-bootstrap";

// TODO: need to add this to state, be able to fetch
// current isFollowing, isSubscribed for this obs/user

const FollowButton = ( { observation, followUser, unfollowUser, subscribe } ) => {
  if ( !observation ) { return ( <div /> ); }
  return (
    <div className="FollowButton">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={ ( event, key ) => {
            if ( key === "user" ) {
              followUser( );
            } else {
              subscribe( );
            }
            return false;
          } }
        >
          <Dropdown.Toggle className="btn-sm">
            Follow
          </Dropdown.Toggle>
          <Dropdown.Menu className="dropdown-menu-right">
            <MenuItem
              key="follow-user"
              eventKey={"user"}
            >
              { observation.user.login }
            </MenuItem>
            <MenuItem
              key="follow-observation"
              eventKey={"observation"}
            >
              This Observation
            </MenuItem>
          </Dropdown.Menu>
        </Dropdown>
      </span>
    </div>
  );
};

FollowButton.propTypes = {
  observation: PropTypes.object,
  followUser: PropTypes.func,
  unfollowUser: PropTypes.func,
  subscribe: PropTypes.func
};

export default FollowButton;
