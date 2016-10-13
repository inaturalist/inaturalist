import { connect } from "react-redux";
import InteractionsTab from "../components/interactions_tab";

function mapStateToProps( state ) {
  return {
    interactions: state.taxon.interactions
  };
}

const InteractionsTabContainer = connect(
  mapStateToProps
)( InteractionsTab );

export default InteractionsTabContainer;
