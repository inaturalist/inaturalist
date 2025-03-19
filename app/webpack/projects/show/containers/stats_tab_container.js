import { connect } from "react-redux";
import StatsTab from "../components/stats_tab";
import {
  fetchQualityGradeCounts,
  fetchIdentificationCategories,
  fetchPopularObservations,
  fetchIconicTaxaCounts
} from "../ducks/project";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchQualityGradeCounts: ( ) => dispatch( fetchQualityGradeCounts( ) ),
    fetchIdentificationCategories: ( ) => dispatch( fetchIdentificationCategories( ) ),
    fetchPopularObservations: ( ) => dispatch( fetchPopularObservations( ) ),
    fetchIconicTaxaCounts: ( ) => dispatch( fetchIconicTaxaCounts( ) ),
    setConfig: attributes => dispatch( setConfig( attributes ) )
  };
}

const StatsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsTab );

export default StatsTabContainer;
