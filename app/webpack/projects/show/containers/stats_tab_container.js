import { connect } from "react-redux";
import StatsTab from "../components/stats_tab";
import { fetchIdentificationCategories,
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
    fetchQualityGradeCounts: ( ) => dispatch( fetchQualityGradeCounts( ) ),
    setConfig: attributes => dispatch( setConfig( attributes ) )
  };
}

const StatsTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( StatsTab );

export default StatsTabContainer;
