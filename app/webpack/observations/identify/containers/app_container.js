import { connect } from "react-redux";
import App from "../components/app";

function mapStateToProps( state ) {
  return {
    blind: state.config.blind
  };
}

function mapDispatchToProps( ) {
  return { };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
