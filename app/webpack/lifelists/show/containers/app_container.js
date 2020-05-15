import { connect } from "react-redux";
import App from "../components/app";
import { setNavView, setDetailsView, zoomToTaxon } from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setNavView: view => dispatch( setNavView( view ) ),
    setDetailsView: view => dispatch( setDetailsView( view ) ),
    zoomToTaxon: taxonID => dispatch( zoomToTaxon( taxonID ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
