import { connect } from "react-redux";
import SimilarTab from "../components/similar_tab";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    taxa: state.taxon.similar
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
