import { connect } from "react-redux";
import Assessment from "../components/assessment";
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

const AssessmentContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Assessment );

export default AssessmentContainer;
