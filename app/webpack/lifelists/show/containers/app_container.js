import { connect } from "react-redux";
import App from "../components/app";
import {
  setNavView, setDetailsView, zoomToTaxon, setDetailsTaxon
} from "../reducers/lifelist";

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
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
