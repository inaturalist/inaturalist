import React from "react";
import { connect } from "react-redux";
import moment from "moment";
import querystring from "querystring";
import _ from "lodash";
import HighlightsTab from "../components/highlights_tab";
import HighlightsTabLegacy from "../components/highlights_tab_legacy";
import gatedComponent from "../../../shared/components/gated_component";
import RESPONSIVE_TEST_GROUPS from "../responsive_test_groups";
import { defaultObservationParams, urlForPlace } from "../../shared/util";
import { showNewTaxon } from "../actions/taxon";
import { fetchRecent, fetchWanted } from "../../shared/ducks/taxon";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapStateToProps( state: Record<string, any> ) {
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

function mapDispatchToProps( dispatch: ( action: unknown ) => void ) {
  return {
    showNewTaxon: ( taxon: unknown ) => dispatch( showNewTaxon( taxon ) ),
    fetchRecent: ( ) => dispatch( fetchRecent( ) ),
    fetchWanted: ( ) => dispatch( fetchWanted( ) )
  };
}

// The legacy module is untyped JS, so its props are asserted to match.
type GateProps = React.ComponentProps<typeof HighlightsTab>;
const LegacyFallback = HighlightsTabLegacy as unknown as React.ComponentType<GateProps>;

const HighlightsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( gatedComponent( RESPONSIVE_TEST_GROUPS, HighlightsTab, LegacyFallback ) );

export default HighlightsTabContainer;
