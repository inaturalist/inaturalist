import { connect } from "react-redux";
import FollowButton from "../components/follow_button";
import { followUser, unfollowUser, subscribe } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation,
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
