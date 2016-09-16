import { connect } from "react-redux";
import App from "../components/app";
import { setConfig } from "../ducks/config";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    place: state.config.preferredPlace
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setPlace: ( place ) => dispatch( setConfig( { preferredPlace: place } ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;

