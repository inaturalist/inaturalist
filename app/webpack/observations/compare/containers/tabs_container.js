import { connect } from "react-redux";
import { chooseTab } from "../ducks/compare";
import { showModal } from "../ducks/taxon_children_modal";
import Tabs from "../components/tabs";

function mapStateToProps( state ) {
  return {
    chosenTab: state.compare.tab
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    chooseTab: tab => dispatch( chooseTab( tab ) ),
    showTaxonChildrenModal: ( ) => dispatch( showModal( ) )
  };
}

const TabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tabs );

export default TabsContainer;
