import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import UmbrellaOverviewTab from "../components/umbrella_overview_tab";
import { fetchPosts } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setConfig: attributes => { dispatch( setConfig( attributes ) ); },
    fetchPosts: ( ) => { dispatch( fetchPosts( ) ); }
  };
}

const UmbrellaOverviewTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( UmbrellaOverviewTab );

export default UmbrellaOverviewTabContainer;
