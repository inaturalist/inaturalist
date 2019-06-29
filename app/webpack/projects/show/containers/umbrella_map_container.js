import { connect } from "react-redux";
import { setConfig, updateCurrentUser } from "../../../shared/ducks/config";
import UmbrellaMap from "../components/umbrella_map";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => dispatch( setConfig( attributes ) ),
    updateCurrentUser: user => dispatch( updateCurrentUser( user ) )
  };
}

const UmbrellaMapContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( UmbrellaMap );

export default UmbrellaMapContainer;
