import { connect } from "react-redux";
import HistoryComparison from "../components/history_comparison";
import {
  setHistoryLayout,
  setHistoryInterval,
  fetchDataForTab
} from "../ducks/compare";

function mapStateToProps( state ) {
  return {
    queries: state.compare.queries,
    histories: state.compare.histories,
    historyLayout: state.compare.historyLayout,
    historyInterval: state.compare.historyInterval
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setHistoryLayout: layout => dispatch( setHistoryLayout( layout ) ),
    setHistoryInterval: interval => {
      dispatch( setHistoryInterval( interval ) );
      dispatch( fetchDataForTab( ) );
    }
  };
}

const HistoryComparisonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( HistoryComparison );

export default HistoryComparisonContainer;
