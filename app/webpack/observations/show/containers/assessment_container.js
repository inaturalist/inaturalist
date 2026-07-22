import { connect } from "react-redux";
import Assessment from "../components/assessment";
import AssessmentLegacy from "../components/assessment_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
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
)( gatedComponent( RESPONSIVE_TEST_GROUPS, Assessment, AssessmentLegacy ) );

export default AssessmentContainer;
