import { connect } from "react-redux";
import SimilarTab from "../components/similar_tab";

function mapStateToProps( state ) {
  return {
    results: state.taxon.similar
  };
}

function mapDispatchToProps( ) {
  return { };
}

const SimilarTabContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SimilarTab );

export default SimilarTabContainer;
