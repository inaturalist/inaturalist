import { connect } from "react-redux";
import Copyright from "../components/copyright";
import { updateSession } from "../ducks/users";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateSession: params => { dispatch( updateSession( params ) ); }
  };
}

const CopyrightContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Copyright );

export default CopyrightContainer;
