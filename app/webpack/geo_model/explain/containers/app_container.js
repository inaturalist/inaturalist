import { connect } from "react-redux";
import App from "../components/app";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return { };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
