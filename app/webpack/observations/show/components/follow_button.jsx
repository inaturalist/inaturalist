import _ from "lodash";
import React, { PropTypes } from "react";
import { Dropdown } from "react-bootstrap";

class FollowButton extends React.Component {

  followStatus( subscription ) {
    if ( subscription ) {
      return subscription.api_status ?
        ( <div className="loading_spinner" /> ) : (
          <span className="unfollow">
            ({ I18n.t( "unfollow" ) })
          </span> );
    }
    return null;
  }

  render( ) {
    const { observation, followUser, unfollowUser,
      subscribe, subscriptions, config, btnClassName } = this.props;
    const loggedIn = config && config.currentUser;
    if ( _.isEmpty( observation ) || !loggedIn ) { return ( <div /> ); }
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
            <Dropdown.Toggle className={ btnClassName }>
              { I18n.t( "follow" ) }
            </Dropdown.Toggle>
            <Dropdown.Menu className="dropdown-menu-right">
              <li className={ followUserPending ? "disabled" : "" }>
                <a
                  href="#"
                  onClick={ e => {
                    e.preventDefault( );
                    followUserAction( );
                    return false;
                  } }
                >
                  { observation.user.login }
                  { this.followStatus( followingUser ) }
                </a>
              </li>
              <li
                className={ followObservationPending ? "disabled" : "" }
              >
                <a
                  href="#"
                  onClick={ e => {
                    e.preventDefault( );
                    followObservationAction( );
                    return false;
                  } }
                >
                  { I18n.t( "this_observation" ) }
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
  subscribe: PropTypes.func,
  btnClassName: PropTypes.string
};

FollowButton.defaultProps = {
  btnClassName: "btn-sm"
};

export default FollowButton;
