import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import UmbrellaOverviewTab from "../components/umbrella_overview_tab";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); }
  };
}

const UmbrellaOverviewTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( UmbrellaOverviewTab );

export default UmbrellaOverviewTabContainer;
