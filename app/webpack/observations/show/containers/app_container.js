import { connect } from "react-redux";
import App from "../components/app";
import { setFlaggingModalState } from "../ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    controlledTerms: state.controlledTerms
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: ( newState ) => { dispatch( setFlaggingModalState( newState ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
