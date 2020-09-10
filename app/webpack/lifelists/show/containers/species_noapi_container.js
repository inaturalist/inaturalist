import _ from "lodash";
import { connect } from "react-redux";
import SpeciesNoAPI from "../components/species_noapi";
import {
  zoomToTaxon, setSpeciesViewRankFilter, setSpeciesViewSort,
  setSpeciesPlaceFilter, setSpeciesViewScrollPage, setDetailsTaxon
} from "../reducers/lifelist";

function mapStateToProps( state ) {
  return {
    config: state.config,
    lifelist: state.lifelist,
    detailsTaxon: state.lifelist.detailsTaxon,
    search: _.get( state.inatAPI, "speciesPlace" )
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    zoomToTaxon: ( taxonID, options ) => dispatch( zoomToTaxon( taxonID, options ) ),
    setDetailsTaxon: ( taxon, options ) => dispatch( setDetailsTaxon( taxon, options ) ),
    setScrollPage: page => dispatch( setSpeciesViewScrollPage( page ) ),
    setSpeciesPlaceFilter: place => dispatch( setSpeciesPlaceFilter( place ) ),
    setRankFilter: value => dispatch( setSpeciesViewRankFilter( value ) ),
    setSort: value => dispatch( setSpeciesViewSort( value ) )
  };
}

const SpeciesNoAPIContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SpeciesNoAPI );

export default SpeciesNoAPIContainer;
