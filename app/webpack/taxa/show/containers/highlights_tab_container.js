import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";
import moment from "moment";
import querystring from "querystring";
import _ from "lodash";
import { defaultObservationParams, urlForPlace } from "../../shared/util";
import { showNewTaxon } from "../actions/taxon";

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
    trendingTaxa: state.taxon.trending ? state.taxon.trending.slice( 0, 20 ) : null,
    wantedTaxa: state.taxon.wanted ? state.taxon.wanted.slice( 0, 20 ) : null,
    discoveries,
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
