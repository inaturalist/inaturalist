import { connect } from "react-redux";
import App from "../components/app";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

const AppContainer = connect(
  mapStateToProps
)( App );

export default AppContainer;
