import { connect } from "react-redux";
import StatsControl from "../components/stats_control";
import { updateSearchParams, fetchObservations } from "../actions";

function mapStateToProps( state ) {
  return {
    stats: state.observationsStats,
    currentQualityGrade: state.searchParams.quality_grade
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    updateQualityGrade: ( qualityGrade ) => {
      dispatch( updateSearchParams( { quality_grade: qualityGrade } ) );
      dispatch( fetchObservations( ) );
    }
  };
}

const StatsControlContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsControl );

export default StatsControlContainer;
