import { connect } from "react-redux";
import FollowButton from "../../show/components/follow_button";
import { followUser, unfollowUser, subscribe } from "../actions";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.currentObservation.observation,
    subscriptions: state.subscriptions
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    followUser: ( ) => { dispatch( followUser( ) ); },
    unfollowUser: ( ) => { dispatch( unfollowUser( ) ); },
    subscribe: ( ) => { dispatch( subscribe( ) ); }
  };
}

const FollowButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FollowButton );

export default FollowButtonContainer;
