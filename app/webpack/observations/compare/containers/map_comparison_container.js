import { connect } from "react-redux";
import MapComparison from "../components/map_comparison";
import { setMapLayout } from "../ducks/compare";

function mapStateToProps( state ) {
  return {
    mapLayout: state.compare.mapLayout,
    queries: state.compare.queries,
    bounds: state.compare.bounds
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setMapLayout: layout => dispatch( setMapLayout( layout ) )
  };
}

const MapComparisonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( MapComparison );

export default MapComparisonContainer;
