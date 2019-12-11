import { connect } from "react-redux";
import FollowButton from "../components/follow_button";
import { followUser, unfollowUser, subscribe } from "../ducks/observation";
import { fetchSubscriptions } from "../ducks/subscriptions";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation,
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
