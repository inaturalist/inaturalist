import { connect } from "react-redux";
import App from "../components/app";
// import { setConfig } from "../../../shared/ducks/config";
import { setOrderBy } from "../ducks/geo_model";

function mapStateToProps( state ) {
  return {
    config: state.config,
    taxa: state.geo_model_taxa
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setOrderBy: ( orderBy, defaultOrder ) => { dispatch( setOrderBy( orderBy, defaultOrder ) ); }
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
