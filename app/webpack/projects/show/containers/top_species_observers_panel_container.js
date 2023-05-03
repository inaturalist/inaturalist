import _ from "lodash";
import { connect } from "react-redux";
import LeaderboardPanel from "../components/leaderboard_panel";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    type: "species_observers",
    leaders: state.project && state.project.observers_loaded
      ? _.reverse( _.sortBy( state.project.observers.results, "species_count" ) ) : null
  };
}

const TopSpeciesObserversPanelContainer = connect(
  mapStateToProps
)( LeaderboardPanel );

export default TopSpeciesObserversPanelContainer;
