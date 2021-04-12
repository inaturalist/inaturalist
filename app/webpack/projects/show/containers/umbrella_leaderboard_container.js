import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import UmbrellaLeaderboard from "../components/umbrella_leaderboard";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); }
  };
}

const UmbrellaLeaderboardContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( UmbrellaLeaderboard );

export default UmbrellaLeaderboardContainer;
