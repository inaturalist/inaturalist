import { connect } from "react-redux";
import ExportModal from "../components/export_modal";
import { setExportModalState } from "../reducers/export_modal";

function mapStateToProps( state ) {
  return {
    show: state.exportModal.show,
    config: state.config,
    lifelist: state.lifelist,
    inatAPI: state.inatAPI
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setExportModalState: newState => dispatch( setExportModalState( newState ) )
  };
}

const ExportModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ExportModal );

export default ExportModalContainer;
