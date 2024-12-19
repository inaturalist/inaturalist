import { confirmResendConfirmation } from "../../../shared/ducks/user_confirmation";

export * from "./comment_actions";
export * from "./current_observation_actions";
export * from "./identification_actions";
export { setConfig, setCurrentUser } from "../../../shared/ducks/config";
export * from "./observations_actions";
export * from "./observations_stats_actions";
export * from "./search_params_actions";
export * from "./finished_modal_actions";

export const showConfirmationModalIfUnconfirmed = ( ) => (
  ( dispatch, getState ) => {
    const { config } = getState( );
    if ( config?.currentUser?.privilegedWith( "interaction" ) ) {
      return;
    }

    dispatch( confirmResendConfirmation( {
      cancellable: false
    } ) );
  }
);
