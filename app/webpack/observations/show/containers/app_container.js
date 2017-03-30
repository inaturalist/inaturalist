import { connect } from "react-redux";
import App from "../components/app";
import { setFlaggingModalState } from "../ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: ( key, value ) => { dispatch( setFlaggingModalState( key, value ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
