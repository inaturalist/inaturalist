import { connect } from "react-redux";
import InteractionsTab from "../components/interactions_tab";

function mapStateToProps( state ) {
  return {
    interactions: state.taxon.interactions,
    nodes: state.interactions.nodes,
    links: state.interactions.links,
    taxon: state.taxon.taxon
  };
}

const InteractionsTabContainer = connect(
  mapStateToProps
)( InteractionsTab );

export default InteractionsTabContainer;
