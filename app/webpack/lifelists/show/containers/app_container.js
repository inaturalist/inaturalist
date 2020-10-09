import { connect } from "react-redux";
import App from "../components/app";
import {
  setNavView, setDetailsView, zoomToTaxon, setDetailsTaxon, setSearchTaxon
} from "../reducers/lifelist";
import { setExportModalState } from "../reducers/export_modal";

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
    setSearchTaxon: taxon => dispatch( setSearchTaxon( taxon ) ),
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) ),
    setExportModalState: newState => dispatch( setExportModalState( newState ) )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
