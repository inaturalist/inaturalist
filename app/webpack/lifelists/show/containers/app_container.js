import { connect } from "react-redux";
import App from "../components/app";
import { togglePhotos } from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    togglePhotos: ( ) => dispatch( togglePhotos( ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
