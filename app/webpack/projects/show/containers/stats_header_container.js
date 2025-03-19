import { connect } from "react-redux";
import StatsHeader from "../components/stats_header";
import { setSelectedTab } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setSelectedTab: tab => { dispatch( setSelectedTab( tab ) ); }
  };
}

const StatsHeaderContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsHeader );

export default StatsHeaderContainer;
