import { connect } from "react-redux";
import StatsControl from "../components/stats_control";

function mapStateToProps( state ) {
  return {
    stats: state.observationsStats
  };
}

function mapDispatchToProps( ) {
  return {};
}

const StatsControlContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsControl );

export default StatsControlContainer;
