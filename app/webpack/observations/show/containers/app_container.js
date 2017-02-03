import { connect } from "react-redux";
import App from "../components/app";
import { addComment, deleteComment, addID, deleteID, restoreID, followUser,
  unfollowUser, subscribe } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    observationPlaces: state.observationPlaces,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addComment: ( body ) => { dispatch( addComment( body ) ); },
    deleteComment: ( id ) => { dispatch( deleteComment( id ) ); },
    addID: ( taxonID, body ) => { dispatch( addID( taxonID, body ) ); },
    deleteID: ( id ) => { dispatch( deleteID( id ) ); },
    restoreID: ( id ) => { dispatch( restoreID( id ) ); },
    followUser: ( ) => { dispatch( followUser( ) ); },
    unfollowUser: ( ) => { dispatch( unfollowUser( ) ); },
    subscribe: ( ) => { dispatch( subscribe( ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
