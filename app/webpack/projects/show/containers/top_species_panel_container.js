import { connect } from "react-redux";
import LeaderboardPanel from "../components/leaderboard_panel";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project,
    type: "species",
    leaders: state.project && state.project.species_loaded ?
      state.project.species.results : null
  };
}

const TopSpeciesPanelContainer = connect(
  mapStateToProps
)( LeaderboardPanel );

export default TopSpeciesPanelContainer;
