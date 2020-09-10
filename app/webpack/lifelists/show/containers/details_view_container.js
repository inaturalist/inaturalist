import { connect } from "react-redux";
import DetailsView from "../components/details_view";
import {
  setDetailsView, zoomToTaxon, setSpeciesPlaceFilter,
  setObservationSort, setDetailsTaxon
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist,
    inatAPI: state.inatAPI
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailsView: view => dispatch( setDetailsView( view ) ),
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) ),
    setSpeciesPlaceFilter: place => dispatch( setSpeciesPlaceFilter( place ) ),
    setObservationSort: sort => dispatch( setObservationSort( sort ) )
  };
}

const DetailsViewContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DetailsView );

export default DetailsViewContainer;
