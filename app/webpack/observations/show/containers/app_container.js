import { connect } from "react-redux";
import App from "../components/app";
import { leaveTestGroup } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    controlledTerms: state.controlledTerms
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    leaveTestGroup: group => { dispatch( leaveTestGroup( group ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
