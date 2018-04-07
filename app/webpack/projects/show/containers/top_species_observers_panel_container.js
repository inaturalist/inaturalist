import { connect } from "react-redux";
import LeaderboardPanel from "../components/leaderboard_panel";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    type: "species_observers",
    leaders: state.project && state.project.species_observers_loaded ?
      state.project.species_observers.results : null
  };
}

const TopSpeciesObserversPanelContainer = connect(
  mapStateToProps
)( LeaderboardPanel );

export default TopSpeciesObserversPanelContainer;
