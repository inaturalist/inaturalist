import { connect } from "react-redux";
import { showAlert } from "../../../shared/ducks/alert_modal";
import { changePassword } from "../ducks/user_settings";
import ChangePassword from "../components/change_password";

function mapStateToProps( ) {
  return { };
}

function mapDispatchToProps( dispatch ) {
  return {
    changePassword: input => dispatch( changePassword( input ) ),
    showAlert: ( message, options ) => dispatch( showAlert( message, options ) )
  };
}

const ChangePasswordContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ChangePassword );

export default ChangePasswordContainer;
