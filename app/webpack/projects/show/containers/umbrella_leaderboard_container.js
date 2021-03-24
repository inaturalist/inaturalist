import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import UmbrellaLeaderboard from "../components/umbrella_leaderboard";
import { fetchUmbrellaStats } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    fetchFullLeaderboard: ( ) => { dispatch( fetchUmbrellaStats( true ) ); }
  };
}

const UmbrellaLeaderboardContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( UmbrellaLeaderboard );

export default UmbrellaLeaderboardContainer;
