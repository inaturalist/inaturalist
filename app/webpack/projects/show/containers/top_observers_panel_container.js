import { connect } from "react-redux";
import LeaderboardPanel from "../components/leaderboard_panel";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    type: "observers",
    leaders: state.project && state.project.observers_loaded ?
      state.project.observers.results : null
  };
}

const TopObserversPanelContainer = connect(
  mapStateToProps
)( LeaderboardPanel );

export default TopObserversPanelContainer;
