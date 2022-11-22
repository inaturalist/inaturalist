import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";
import moment from "moment";
import querystring from "querystring";
import _ from "lodash";
import { defaultObservationParams, urlForPlace } from "../../shared/util";
import { showNewTaxon } from "../actions/taxon";
import { fetchRecent, fetchWanted } from "../../shared/ducks/taxon";

function mapStateToProps( state ) {
  const trendingParams = Object.assign( { }, defaultObservationParams( state ), {
    view: "species",
    d1: moment( ).subtract( 1, "month" ).format( "YYYY-MM-DD" )
  } );
  let discoveries;
  if ( state.taxon.recent ) {
    discoveries = _.uniqBy(
      _.sortBy( state.taxon.recent.results, r => r.taxon.rank_level ),
      r => r.identification.observation.id
    );
  }
  return {
    wantedShown: state.taxon.taxon.complete_species_count > 0,
    discoveriesShown: state.taxon.taxon.complete_species_count > 0,
    trendingTaxa: state.taxon.trending ? state.taxon.trending.slice( 0, 20 ) : null,
    wantedTaxa: state.taxon.wanted,
    discoveries,
    trendingUrl: `/observations?${querystring.stringify( trendingParams )}`,
    placeName: state.config.chosenPlace ? state.config.chosenPlace.display_name : null,
    placeUrl: state.config.chosenPlace ? urlForPlace( state.config.chosenPlace ) : null,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showNewTaxon: taxon => dispatch( showNewTaxon( taxon ) ),
    fetchRecent: ( ) => dispatch( fetchRecent( ) ),
    fetchWanted: ( ) => dispatch( fetchWanted( ) )
  };
}

const HighlightsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( HighlightsTab );

export default HighlightsTabContainer;
