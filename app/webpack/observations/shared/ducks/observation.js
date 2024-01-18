import _ from "lodash";
import inatjs from "inaturalistjs";
import { handleAPIError } from "../../show/ducks/confirm_modal";
import util from "../../show/util";
import { setProjectFieldsModalState } from "../../show/ducks/project_fields_modal";

let lastAction;
export function getActionTime( ) {
  const currentTime = new Date( ).getTime( );
  lastAction = currentTime;
  return currentTime;
}

export function hasObsAndLoggedIn( state ) {
  return (
    state
    && state.config
    && state.config.currentUser
    && ( state.observation || (
      state.currentObservation && state.currentObservation.observation
    ) )
  );
}

export function afterAPICall(
  observation,
  fetchObservation,
  options = { }
) {
  return dispatch => {
    if ( options.error ) {
      dispatch(
        handleAPIError(
          options.error,
          options.errorMessage || I18n.t( "failed_to_save_record" )
        )
      );
    }
    if ( options.callback ) {
      options.callback( );
      return;
    }
    if (
      ( options.actionTime && lastAction !== options.actionTime )
      || !observation
    ) {
      return;
    }
    fetchObservation( );
  };
}

export function callAPI(
  observation,
  method,
  payload,
  fetchObservation,
  options = { }
) {
  return dispatch => {
    const opts = { ...options };
    // only need to keep track of the times of non-custom callbacks
    if ( !options.callback ) {
      opts.actionTime = getActionTime( );
    }
    method( payload ).then( ( ) => {
      dispatch( afterAPICall( observation, fetchObservation, opts ) );
    } ).catch( e => {
      opts.error = e;
      dispatch( afterAPICall( observation, fetchObservation, opts ) );
    } );
  };
}

export function addToProjectSubmit(
  observation,
  project,
  setAttributes,
  fetchObservation
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newProjectObs = _.clone( observation.project_observations );
    newProjectObs.unshift( {
      project,
      user_id: state.config.currentUser.id,
      user: state.config.currentUser,
      api_status: "saving"
    } );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );

    const { testingApiV2 } = state.config;
    let payload = {
      id: project.id,
      observation_id: observation.id
    };
    let endpoint = inatjs.projects.add;
    if ( testingApiV2 ) {
      payload = {
        project_observation: {
          project_id: project.id,
          observation_id: observation.uuid
        }
      };
      endpoint = inatjs.project_observations.create;
    }
    dispatch( callAPI( observation, endpoint, payload, fetchObservation, {
      errorMessage: `Failed to add to project ${project.title}`
    } ) );
  };
}

export function addToProject(
  observation,
  project,
  setAttributes,
  fetchObservation,
  options = { }
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const missingFields = util.observationMissingProjectFields( observation, project );
    if ( !_.isEmpty( missingFields ) && !options.ignoreMissing ) {
      // there are empty required project fields, so show the modal
      dispatch( setProjectFieldsModalState( {
        show: true,
        project,
        onSubmit: ( ) => {
          dispatch( setProjectFieldsModalState( { show: false } ) );
          // user may have chosen to leave some non-required fields empty
          dispatch( addToProject(
            observation,
            project,
            setAttributes,
            fetchObservation,
            { ignoreMissing: true }
          ) );
        }
      } ) );
      return;
    }
    // there are no empty required fields, so proceed with adding
    dispatch( addToProjectSubmit( observation, project, setAttributes, fetchObservation ) );
  };
}

export function removeFromProject(
  observation,
  project,
  setAttributes,
  fetchObservation
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const poToDelete = _.find(
      observation.project_observations,
      po => po.project.id === project.id
    );
    const newProjectObs = observation.project_observations.filter( po => (
      po.project.id !== project.id
    ) );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );
    const { testingApiV2 } = state.config;
    if ( testingApiV2 ) {
      dispatch( callAPI(
        observation,
        inatjs.project_observations.delete,
        { id: poToDelete.uuid || poToDelete.id },
        fetchObservation
      ) );
    } else {
      const payload = { id: project.id, observation_id: observation.id };
      dispatch( callAPI( observation, inatjs.projects.remove, payload, fetchObservation ) );
    }
  };
}

export function joinProject(
  observation,
  project,
  setAttributes,
  fetchObservation
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( !project || !project.id ) { return; }
    dispatch( callAPI(
      observation,
      inatjs.projects.join,
      { id: project.id },
      fetchObservation
    ) );
  };
}

export function addObservationFieldValue(
  observation,
  setAttributes,
  fetchObservation,
  options
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) || !options.observationField ) { return; }
    const { testingApiV2 } = state.config;
    const newOfvs = _.clone( observation.ofvs );
    newOfvs.unshift( {
      datatype: options.observationField.datatype,
      name: options.observationField.name,
      value: options.value,
      observation_field: options.observationField,
      api_status: "saving",
      taxon: options.taxon
    } );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    const payload = {
      observation_field_value: {
        observation_field_id: options.observationField.id,
        observation_id: testingApiV2
          ? observation.uuid
          : observation.id,
        value: options.value
      }
    };
    dispatch( callAPI(
      observation,
      inatjs.observation_field_values.create,
      payload,
      fetchObservation
    ) );
  };
}

export function updateObservationFieldValue(
  observation,
  id,
  setAttributes,
  fetchObservation,
  options
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) || !options.observationField ) { return; }
    const { testingApiV2 } = state.config;
    const newOfvs = observation.ofvs.map( ofv => (
      ofv.uuid === id ? {
        datatype: options.observationField.datatype,
        name: options.observationField.name,
        value: options.value,
        observation_field: options.observationField,
        api_status: "saving",
        taxon: options.taxon
      } : ofv ) );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    const payload = {
      uuid: id,
      observation_field_value: {
        observation_field_id: options.observationField.id,
        observation_id: testingApiV2
          ? observation.uuid
          : observation.id,
        value: options.value
      }
    };
    dispatch( callAPI(
      observation,
      inatjs.observation_field_values.update,
      payload,
      fetchObservation
    ) );
  };
}

export function removeObservationFieldValue(
  observation,
  id,
  setAttributes,
  fetchObservation
) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newOfvs = observation.ofvs.map( ofv => (
      ofv.uuid === id ? { ...ofv, api_status: "deleting" } : ofv ) );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    dispatch( callAPI(
      observation,
      inatjs.observation_field_values.delete,
      { id },
      fetchObservation
    ) );
  };
}
