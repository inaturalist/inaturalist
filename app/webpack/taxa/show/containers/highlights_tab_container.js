import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";
import moment from "moment";
import querystring from "querystring";
import { defaultObservationParams } from "../../shared/util";

function mapStateToProps( state ) {
  const trendingParams = Object.assign( { }, defaultObservationParams( state ), {
    view: "species",
    d1: moment( ).subtract( 1, "month" ).format( "YYYY-MM-DD" )
  } );
  const rareParams = Object.assign( { }, defaultObservationParams( state ), {
    view: "species",
    order: "asc"
  } );
  return {
    trendingTaxa: state.taxon.trending ? state.taxon.trending.slice( 0, 20 ) : [],
    rareTaxa: state.taxon.rare ? state.taxon.rare.slice( 0, 20 ) : [],
    trendingUrl: `/observations?${querystring.stringify( trendingParams )}`,
    rareUrl: `/observations?${querystring.stringify( rareParams )}`
  };
}

function mapDispatchToProps( ) {
  return {};
}

const HighlightsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( HighlightsTab );

export default HighlightsTabContainer;
