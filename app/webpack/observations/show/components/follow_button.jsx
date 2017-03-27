import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown } from "react-bootstrap";

// TODO: need to add this to state, be able to fetch
// current isFollowing, isSubscribed for this obs/user


class FollowButton extends React.Component {

  followStatus( subscription ) {
    if ( subscription ) {
      return subscription.api_status ?
        ( <div className="loading_spinner" /> ) : (
          <span className="unfollow">
            (Unfollow)
          </span> );
    }
    return null;
  }

  render( ) {
    const { observation, followUser, unfollowUser,
      subscribe, subscriptions, config } = this.props;
    const loggedIn = config && config.currentUser;
    if ( !observation || !loggedIn ) { return ( <div /> ); }
    let followingUser;
    let followingObservation;
    _.each( subscriptions, s => {
      if ( s.resource_type === "User" ) { followingUser = s; }
      if ( s.resource_type === "Observation" ) { followingObservation = s; }
    } );
    const followUserPending = followingUser && followingUser.api_status;
    const followObservationPending = followingObservation && followingObservation.api_status;
    let followUserAction;
    let followObservationAction;
    if ( !followUserPending && !followObservationPending ) {
      followUserAction = followingUser ? unfollowUser : followUser;
      followObservationAction = subscribe;
    }
    return (
      <div className="FollowButton">
        <span className="control-group">
          <Dropdown
            id="grouping-control"
          >
            <Dropdown.Toggle className="btn-sm">
              Follow
            </Dropdown.Toggle>
            <Dropdown.Menu className="dropdown-menu-right">
              <li className={ followUserPending ? "disabled" : "" }>
                <a href="#" onClick={ followUserAction }>
                  { observation.user.login }
                  { this.followStatus( followingUser ) }
                </a>
              </li>
              <li
                className={ followObservationPending ? "disabled" : "" }
              >
                <a href="#" onClick={ followObservationAction }>
                  This observation
                  { this.followStatus( followingObservation ) }
                </a>
              </li>
            </Dropdown.Menu>
          </Dropdown>
        </span>
      </div>
    );
  }
}

FollowButton.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  subscriptions: PropTypes.array,
  followUser: PropTypes.func,
  unfollowUser: PropTypes.func,
  subscribe: PropTypes.func
};

export default FollowButton;
