import _ from "lodash";
import { connect } from "react-redux";
import ResearchGradeProgress from "../components/research_grade_progress";

function mapStateToProps( state ) {
  return {
    config: state.config,
    observation: state.observation,
    qualityMetrics: {
      ..._.groupBy( state.qualityMetrics, "metric" ),
      ..._.groupBy( state.observation.votes, "vote_scope" )
    }
  };
}

const ResearchGradeProgressContainer = connect(
  mapStateToProps
)( ResearchGradeProgress );

export default ResearchGradeProgressContainer;
