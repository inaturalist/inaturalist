import { connect } from "react-redux";
import FollowButton from "../../show/components/follow_button";
import { followUser, unfollowUser, subscribe } from "../actions";
import { fetchSubscriptions } from "../../show/ducks/subscriptions";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.currentObservation.observation,
    subscriptions: state.subscriptions.subscriptions,
    subscriptionsLoaded: state.subscriptions.loaded
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    followUser: ( ) => dispatch( followUser( ) ),
    unfollowUser: ( ) => dispatch( unfollowUser( ) ),
    subscribe: ( ) => dispatch( subscribe( ) ),
    fetchSubscriptions: options => dispatch( fetchSubscriptions( options ) )
  };
}

const FollowButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FollowButton );

export default FollowButtonContainer;
