import { connect } from "react-redux";
import AdditionalObservers from "../components/additional_observers";
import { addAdditionalObserver, removeAdditionalObserver } from "../ducks/additional_observers";

function mapStateToProps( state ) {
  const viewerIsObserver = !!(
    state.config && state.config.currentUser
    && state.observation && state.observation.user
    && state.config.currentUser.id === state.observation.user.id
  );
  return {
    config: state.config,
    observation: state.observation,
    viewerIsObserver
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addAdditionalObserver: user => dispatch( addAdditionalObserver( user ) ),
    removeAdditionalObserver: userId => dispatch( removeAdditionalObserver( userId ) )
  };
}

const AdditionalObserversContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AdditionalObservers );

export default AdditionalObserversContainer;
