import { connect } from "react-redux";
import App from "../components/app";
import { setConfig, updateCurrentUser } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    sideBarHidden: state.config.sideBarHidden
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setSideBarHidden: hidden => {
      dispatch( setConfig( { sideBarHidden: hidden } ) );
      dispatch( updateCurrentUser( { prefers_identify_side_bar: !hidden } ) );
    }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
