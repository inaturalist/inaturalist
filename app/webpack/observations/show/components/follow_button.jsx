import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown } from "react-bootstrap";

const FollowButton = ( {
  btnClassName,
  config,
  fetchSubscriptions,
  followUser,
  observation,
  subscribe,
  subscriptions,
  subscriptionsLoaded,
  unfollowUser
} ) => {
  const followStatus = ( subscription, unfollowText ) => {
    if ( subscription ) {
      return subscription.api_status
        ? <div className="loading_spinner" />
        : (
          <span className="unfollow">
            { unfollowText }
          </span>
        );
    }
    return null;
  };
  let dropdownMenu;
  if ( subscriptionsLoaded ) {
    const loggedIn = config && config.currentUser;
    if ( _.isEmpty( observation ) || !loggedIn ) { return ( <div /> ); }
    let userSubscription;
    let observationSubscription;
    _.each( subscriptions, s => {
      if ( s.resource_type === "User" ) { userSubscription = s; }
      if ( s.resource_type === "Observation" ) { observationSubscription = s; }
    } );
    const followUserPending = userSubscription && userSubscription.api_status;
    const followObservationPending = observationSubscription && observationSubscription.api_status;
    let followUserAction;
    let followObservationAction;
    if ( !followUserPending && !followObservationPending ) {
      followUserAction = userSubscription ? unfollowUser : followUser;
      followObservationAction = subscribe;
    }
    let followUserButtonContent = I18n.t( "follow_user", { user: observation?.user?.login } );
    if ( userSubscription ) {
      followUserButtonContent = followStatus(
        userSubscription,
        I18n.t( "unfollow_user", { user: observation?.user?.login } )
      );
    }
    let followObservationButtonContent = I18n.t( "follow_observation" );
    if ( observationSubscription ) {
      followObservationButtonContent = followStatus(
        observationSubscription,
        I18n.t( "unfollow_observation" )
      );
    }
    dropdownMenu = (
      <Dropdown.Menu className="dropdown-menu-right">
        <li className={followUserPending ? "disabled" : ""}>
          <a
            href="#"
            onClick={e => {
              e.preventDefault( );
              followUserAction( );
              return false;
            }}
          >
            { followUserButtonContent }
          </a>
        </li>
        <li
          className={followObservationPending ? "disabled" : ""}
        >
          <a
            href="#"
            onClick={e => {
              e.preventDefault( );
              followObservationAction( );
              return false;
            }}
          >
            { followObservationButtonContent }
          </a>
        </li>
      </Dropdown.Menu>
    );
  } else {
    dropdownMenu = (
      <Dropdown.Menu className="dropdown-menu-right">
        <li className="disabled" />
      </Dropdown.Menu>
    );
  }
  return (
    <div className="FollowButton">
      <span className="control-group">
        <Dropdown
          id="grouping-control"
          onToggle={show => {
            if ( show && !subscriptionsLoaded ) {
              fetchSubscriptions( { observation } );
            }
          }}
        >
          <Dropdown.Toggle className={btnClassName}>
            { I18n.t( "follow" ) }
          </Dropdown.Toggle>
          { dropdownMenu }
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
  subscribe: PropTypes.func,
  btnClassName: PropTypes.string,
  subscriptionsLoaded: PropTypes.bool,
  fetchSubscriptions: PropTypes.func
};

FollowButton.defaultProps = {
  btnClassName: "btn-sm"
};

export default FollowButton;
