import { connect } from "react-redux";
import StatsTab from "../components/stats_tab";
import {
  fetchIdentificationCategories,
  fetchPopularObservations,
  fetchQualityGradeCounts } from "../ducks/project";
import { setConfig } from "../../../shared/ducks/config";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    fetchIdentificationCategories: ( ) => dispatch( fetchIdentificationCategories( ) ),
    fetchPopularObservations: ( ) => dispatch( fetchPopularObservations( ) ),
    fetchQualityGradeCounts: ( ) => dispatch( fetchQualityGradeCounts( ) ),
    setConfig: attributes => dispatch( setConfig( attributes ) )
  };
}

const StatsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsTab );

export default StatsTabContainer;
