import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";

function mapStateToProps( state ) {
  return {
    trendingTaxa: state.taxon.trending ? state.taxon.trending.slice( 0, 20 ) : [],
    rareTaxa: state.taxon.rare ? state.taxon.rare.slice( 0, 20 ) : []
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
