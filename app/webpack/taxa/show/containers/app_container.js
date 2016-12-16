import { connect } from "react-redux";
import App from "../components/app";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon
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

