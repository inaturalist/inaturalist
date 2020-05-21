import { connect } from "react-redux";
import SpeciesNoAPI from "../components/species_noapi";
import {
  zoomToTaxon, setSpeciesViewRankFilter, setSpeciesViewSort,
  setSpeciesPlaceFilter, setSpeciesViewScrollPage
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist,
    detailsTaxon: state.lifelist.detailsTaxon
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) ),
    setScrollPage: page => dispatch( setSpeciesViewScrollPage( page ) ),
    setPlaceFilter: placeID => dispatch( setSpeciesPlaceFilter( placeID ) ),
    setRankFilter: value => dispatch( setSpeciesViewRankFilter( value ) ),
    setSort: value => dispatch( setSpeciesViewSort( value ) )
  };
}

const SpeciesNoAPIContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesNoAPI );

export default SpeciesNoAPIContainer;
