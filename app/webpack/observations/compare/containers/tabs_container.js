import { connect } from "react-redux";
// import { setConfig } from "../../../shared/ducks/config";
import { chooseTab } from "../ducks/compare";
import Tabs from "../components/tabs";

function mapStateToProps( state ) {
  return {
    chosenTab: state.config.chosenTab
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    chooseTab: tab => dispatch( chooseTab( tab ) )
  };
}

const TabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tabs );

export default TabsContainer;
