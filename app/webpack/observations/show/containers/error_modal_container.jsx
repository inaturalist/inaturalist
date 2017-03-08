import { connect } from "react-redux";
import ErrorModal from "../components/error_modal";
import { setErrorModalState } from "../ducks/error_modal";

function mapStateToProps( state ) {
  return {
    config: state.config,
    state: state.errorModal
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setErrorModalState: ( key, value ) => { dispatch( setErrorModalState( key, value ) ); }
  };
}

const ErrorModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ErrorModal );

export default ErrorModalContainer;
