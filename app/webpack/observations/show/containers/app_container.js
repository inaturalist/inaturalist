import { connect } from "react-redux";
import App from "../components/app";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

const AppContainer = connect(
  mapStateToProps
)( App );

export default AppContainer;
