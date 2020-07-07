import { connect } from "react-redux";
import AlertModal from "../components/alert_modal";
import {
  hideAlert
} from "../actions";

function mapStateToProps( state ) {
  return state.alert;
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => dispatch( hideAlert( ) )
  };
}

const AlertModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( AlertModal );

export default AlertModalContainer;
