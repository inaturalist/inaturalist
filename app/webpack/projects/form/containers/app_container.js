import { connect } from "react-redux";
import App from "../components/app";
import { createNewProject } from "../form_reducer";
import { performOrOpenConfirmationModal } from "../../../shared/ducks/user_confirmation";

function mapStateToProps( state ) {
  return {
    config: state.config,
    form: state.form
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    createNewProject: type => {
      dispatch( createNewProject( type ) );
    },
    performOrOpenConfirmationModal: ( method, options = { } ) => (
      dispatch( performOrOpenConfirmationModal( method, options ) )
    )
  };
}

const AppContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( App );

export default AppContainer;
