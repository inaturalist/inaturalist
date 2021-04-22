import { connect } from "react-redux";
import ProgressChart from "../components/progress_chart";
import { fetchObservationsStats } from "../actions/observations_stats_actions";


function mapStateToProps( state ) {
  const reviewed = state.observationsStats.reviewed || 0;
  const total = state.observationsStats.total || 0;
  return {
    reviewed,
    unreviewed: total - reviewed
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchObservationsStats: ( ) => dispatch( fetchObservationsStats( ) )
  };
}

const ProgressChartContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ProgressChart );

export default ProgressChartContainer;
