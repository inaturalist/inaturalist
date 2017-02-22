import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown, MenuItem } from "react-bootstrap";

// TODO: need to add this to state, be able to fetch
// current isFollowing, isSubscribed for this obs/user

const FollowButton = ( { observation, followUser, unfollowUser, subscribe,
                         subscriptions, config } ) => {
  const loggedIn = config && config.currentUser;
  if ( !observation || !loggedIn ) { return ( <div /> ); }
  let followingUser;
  let followingObservation;
  _.each( subscriptions, s => {
    if ( s.resource_type === "User" ) { followingUser = true; }
    if ( s.resource_type === "Observation" ) { followingObservation = true; }
  } );
  const followUserItem = followingUser ? observation.user.login : (
    <span>
      { observation.user.login }
      <span className="unfollow">
        (Unfollow)
      </span>
    </span>
  );
  const followObservationItem = followingObservation ? "This Observation" : (
    <span>
      This observation
      <span className="unfollow">
        (Unfollow)
      </span>
    </span>
  );
  return (
    <div className="FollowButton">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onSelect={ ( event, key ) => {
            if ( key === "user" ) {
              if ( followingUser ) {
                unfollowUser( );
              } else {
                followUser( );
              }
            } else {
              // subscribe is its own opposite
              subscribe( );
            }
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
              { followUserItem }
            </MenuItem>
            <MenuItem
              key="follow-observation"
              eventKey={"observation"}
            >
              { followObservationItem }
            </MenuItem>
          </Dropdown.Menu>
        </Dropdown>
      </span>
    </div>
  );
};

FollowButton.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  subscriptions: PropTypes.array,
  followUser: PropTypes.func,
  unfollowUser: PropTypes.func,
  subscribe: PropTypes.func
};

export default FollowButton;
