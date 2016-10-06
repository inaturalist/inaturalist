import { connect } from "react-redux";
import NamesTab from "../components/names_tab.jsx";

function mapStateToProps( state ) {
  return {
    taxon: state.taxon.taxon,
    names: state.taxon.names
  };
}

const NamesTabContainer = connect( mapStateToProps )( NamesTab );

export default NamesTabContainer;
