import { connect } from "react-redux";
import HighlightsTab from "../components/highlights_tab";

function mapStateToProps( state ) {
  return {
    trendingTaxa: state.taxon.trending,
    rareTaxa: state.taxon.rare
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
