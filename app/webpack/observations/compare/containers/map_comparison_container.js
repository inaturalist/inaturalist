import { connect } from "react-redux";
import MapComparison from "../components/map_comparison";
import { setMapLayout } from "../ducks/compare";
import { updateCurrentUser } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    mapLayout: state.compare.mapLayout,
    queries: state.compare.queries,
    bounds: state.compare.bounds,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setMapLayout: layout => dispatch( setMapLayout( layout ) ),
    updateCurrentUser: user => dispatch( updateCurrentUser( user ) )
  };
}

const MapComparisonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( MapComparison );

export default MapComparisonContainer;
