import { connect } from "react-redux";
import OverviewTab from "../components/overview_tab";

function mapStateToProps( state ) {
  return {
    config: state.config,
    project: state.project
  };
}

const OverviewTabContainer = connect(
  mapStateToProps
)( OverviewTab );

export default OverviewTabContainer;
