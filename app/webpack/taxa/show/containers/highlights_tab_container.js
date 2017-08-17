import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";
import moment from "moment";
import querystring from "querystring";
import { defaultObservationParams, urlForPlace } from "../../shared/util";
import { showNewTaxon } from "../actions/taxon";

function mapStateToProps( state ) {
  const trendingParams = Object.assign( { }, defaultObservationParams( state ), {
    view: "species",
    d1: moment( ).subtract( 1, "month" ).format( "YYYY-MM-DD" )
  } );
  return {
    trendingTaxa: state.taxon.trending ? state.taxon.trending.slice( 0, 20 ) : null,
    rareTaxa: state.taxon.rare ? state.taxon.rare.slice( 0, 20 ) : null,
    discoveries: state.taxon.recent ? state.taxon.recent.results : null,
    trendingUrl: `/observations?${querystring.stringify( trendingParams )}`,
    placeName: state.config.chosenPlace ? state.config.chosenPlace.display_name : null,
    placeUrl: state.config.chosenPlace ? urlForPlace( state.config.chosenPlace ) : null
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) )
  };
}

const HighlightsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( HighlightsTab );

export default HighlightsTabContainer;
