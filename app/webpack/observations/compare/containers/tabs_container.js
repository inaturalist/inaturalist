import { connect } from "react-redux";
import { chooseTab, setColorScheme } from "../ducks/compare";
import { showModal } from "../ducks/taxon_children_modal";
import Tabs from "../components/tabs";

function mapStateToProps( state ) {
  return {
    chosenTab: state.compare.tab,
    colorScheme: state.compare.colorScheme
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    chooseTab: tab => dispatch( chooseTab( tab ) ),
    showTaxonChildrenModal: ( ) => dispatch( showModal( ) ),
    chooseColorScheme: colorScheme => dispatch( setColorScheme( colorScheme ) )
  };
}

const TabsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Tabs );

export default TabsContainer;
