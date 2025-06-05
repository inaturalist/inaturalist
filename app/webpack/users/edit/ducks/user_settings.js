import React from "react";
import inatjs from "inaturalistjs";
import _ from "lodash";
import { fetchRelationships, updateBlockedAndMutedUsers } from "./relationships";
import { setConfirmEmailModalState } from "../../../shared/ducks/confirm_email_modal";
import { setConfirmModalState } from "../../../shared/ducks/confirm_modal";
import RejectedFilesError from "../../../shared/components/rejected_files_error";
import { fetchNetworkSites } from "./network_sites";
import { fetchFavoriteProjects } from "./favorite_projects";

const SET_USER_DATA = "user/edit/SET_USER_DATA";
const SAVED = "saved";
const UNSAVED = "unsaved";
export const NO_CHANGE = "no change";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_USER_DATA:
      return { ...action.userData };
    default:
  }
  return state;
}

export function setUserSettings( userData, savedStatus = UNSAVED ) {
  if ( savedStatus !== NO_CHANGE ) userData.saved_status = savedStatus;

  return {
    type: SET_USER_DATA,
    userData
  };
}

export function fetchUserSettings( savedStatus, relationshipsPage ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    const params = {
      useAuth: true,
      fields: "all"
    };
    const initialLoad = _.isEmpty( userSettings );
    inatjs.users.me( params ).then( ( { results } ) => {
      // this is kind of unnecessary, but removing these since they're read-only keys
      // and don't need to be included in UI or users.update
      const keysToIgnore = [
        "activity_count",
        "created_at",
        "identifications_count",
        "journal_posts_count",
        "login_autocomplete",
        "login_exact",
        "name_autocomplete",
        "observations_count",
        "prefers_automatic_taxon_changes",
        "spam",
        "species_count",
        "suspended",
        "universal_search_rank",
        "annotated_observations_count"
      ];

      const newUserSettings = Object.keys( results[0] ).reduce( ( object, key ) => {
        if ( !keysToIgnore.includes( key ) ) {
          object[key] = results[0][key];
        }
        return object;
      }, {} );

      // We may have pre-set confirmation_sent_at before actually requesting
      // it, so we're keeping it there until we get a new value from the
      // server
      if ( userSettings.confirmation_sent_at && !newUserSettings.confirmation_sent_at ) {
        newUserSettings.confirmation_sent_at = userSettings.confirmation_sent_at;
      }

      dispatch( setUserSettings( newUserSettings, savedStatus ) );

      if ( initialLoad ) {
        dispatch( fetchRelationships( true ) );
      }
      if ( relationshipsPage ) {
        dispatch( updateBlockedAndMutedUsers( ) );
      }

      dispatch( fetchFavoriteProjects( newUserSettings ) );

      const { sites } = getState( );
      // If the user is affiliated with a site we don't know about, try fetching
      // the sites again
      if ( sites && sites.sites && newUserSettings.site_id ) {
        const siteIds = sites.sites.map( s => s.id );
        if ( siteIds.indexOf( newUserSettings.site_id ) < 0 ) {
          dispatch( fetchNetworkSites( ) );
        }
      }
    } ).catch( e => console.log( `Failed to fetch via users.me: ${e}` ) );
  };
}

export async function handleSaveError( e ) {
  // If there's no response, this wasn't an HTTP error response and we don't
  // know what to show the user
  if ( !e.response ) {
    alert( I18n.t( "doh_something_went_wrong_error", { error: e.message } ) );
    throw e;
  }
  // If the user is no longer authenticated, reload the window since they were
  // probably signed out for some reason
  if ( e.response.status === 401 ) {
    window.location.reload( );
    return {};
  }
  const body = await e.response.json( );
  if (
    Array.isArray( body?.errors )
    && _.isObject( body?.errors?.[0] )
    && body?.errors?.[0].from === "externalAPI"
    && body?.errors?.[0]?.message
  ) {
    // apiv2 passes on errors from rails in an object, e.g.:
    //   { errors: [{ from: "externalAPI", message: "**JSON encoded errors object**"}] }
    return JSON.parse( body.errors[0].message ).errors;
  }
  if ( body && body.errors ) return body.errors;
  if ( body && body.error && body.error.original ) return body.error.original.errors;
  return null;
}

export function postUserSettings( options = {} ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    const { id } = userSettings;

    const params = {
      id,
      user: { ...userSettings }
    };

    const topLevelAttributes = [
      "icon_delete"
    ];

    // move these attributes so they're nested under params, not params.user
    topLevelAttributes.forEach( attr => {
      if ( !userSettings[attr] ) return;

      params[attr] = true;
      delete params.user[attr];
    } );

    // If we only want to update certain attributes, filter out everything but
    // those
    if ( options.only ) {
      params.user = Object.fromEntries(
        Object.entries( params.user ).filter( ( [key] ) => options.only.includes( key ) )
      );
    }

    // don't include the icon value from users.me, otherwise, will get a 500 error
    if ( typeof params.user.icon === "string" ) {
      delete params.user.icon;
    }

    // could leave these, but they're unpermitted parameters
    delete params.user.blocked_user_ids;
    delete params.user.confirmation_sent_at;
    delete params.user.confirmed_at;
    delete params.user.errors;
    delete params.user.icon_url;
    delete params.user.id;
    delete params.user.monthly_supporter;
    delete params.user.muted_user_ids;
    delete params.user.orcid;
    delete params.user.taxon_name_priorities;
    delete params.user.privileges;
    delete params.user.roles;
    delete params.user.saved_status;
    delete params.user.site;
    delete params.user.unconfirmed_email;
    delete params.user.updated_at;
    delete params.user.place_id;

    // fetching user settings here to get the source of truth
    // currently users.me returns different results than
    // dispatching setUserSettings( results[0] ) from users.update response
    return inatjs.users.update( params, { useAuth: true } )
      .then( ( ) => {
        // If we want to update without fetching the user again...
        if ( options.skipFetch ) return null;

        return dispatch( fetchUserSettings( SAVED ) );
      } )
      .catch( e => handleSaveError( e ).then( errors => {
        userSettings.errors = errors;
        dispatch( setUserSettings( userSettings, null ) );
      } ) );
  };
}

export function handleCheckboxChange( e ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );

    if ( e.target.name === "prefers_no_email" ) {
      userSettings[e.target.name] = !e.target.checked;
    } else if ( e.target.name.includes( "email_suppression_" ) ) {
      const name = e.target.name.replace( "email_suppression_", "" );
      if ( e.target.checked ) {
        userSettings.email_suppression_types = ( userSettings.email_suppression_types || [] )
          .filter( v => v !== name );
      } else {
        userSettings.email_suppression_types = [...new Set( [
          ...( userSettings.email_suppression_types || [] ), name
        ] )];
      }
    } else {
      userSettings[e.target.name] = e.target.checked;
    }
    dispatch( setUserSettings( userSettings ) );
  };
}

export function handleDisplayNames( { target } ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    const { value } = target;

    if ( value === "prefers_common_names" ) {
      userSettings.prefers_common_names = true;
      userSettings.prefers_scientific_name_first = false;
    } else if ( value === "prefers_scientific_name_first" ) {
      userSettings.prefers_common_names = true;
      userSettings.prefers_scientific_name_first = true;
    } else {
      userSettings.prefers_common_names = false;
      userSettings.prefers_scientific_name_first = false;
    }
    dispatch( setUserSettings( userSettings ) );
  };
}

export function updateUserData( updates, options = {} ) {
  return ( dispatch, getState ) => {
    const { userSettings: userData } = getState( );
    dispatch( setUserSettings( { ...userData, ...updates }, options.savedStatus ) );
  };
}

export function handleInputChange( e ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    userSettings[e.target.name] = e.target.value;
    dispatch( setUserSettings( userSettings ) );
  };
}

export function handleCustomDropdownSelect( eventKey, name ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    userSettings[name] = eventKey;
    dispatch( setUserSettings( userSettings ) );
  };
}

export function handlePlaceAutocomplete( { item }, name ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );

    if ( userSettings[name] === null && item.id === 0 ) {
      // do nothing if the afterClear is triggered when the place input field starts empty
      // this ensures save settings button shows correctly
      return;
    }

    userSettings[name] = item.id;
    dispatch( setUserSettings( userSettings ) );
  };
}

export function handlePhotoUpload( e ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    userSettings.icon = e.target.files[0];
    dispatch( setUserSettings( userSettings ) );
  };
}

export function onFileDrop( droppedFiles, rejectedFiles ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );

    if ( rejectedFiles && rejectedFiles.length > 0 ) {
      /* eslint-disable react/jsx-filename-extension */
      const message = (
        <RejectedFilesError
          rejectedFiles={rejectedFiles}
          supportedFilesRegex="gif|png|jpe?g"
          unsupportedFileTypeMessage={I18n.t( "views.users.edit.errors.unsupported_file_type" )}
        />
      );
      if ( message ) {
        dispatch( setConfirmModalState( {
          show: true,
          message,
          confirmText: I18n.t( "ok" )
        } ) );
      }
      return;
    }
    if ( _.isEmpty( droppedFiles ) ) { return; }
    const droppedFile = droppedFiles[0];
    if ( droppedFile.type.match( /^image\// ) ) {
      userSettings.icon = droppedFile;
      dispatch( setUserSettings( userSettings ) );
    }
  };
}

export function removePhoto( ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    userSettings.icon = null;
    userSettings.icon_url = null;
    userSettings.icon_delete = true;
    dispatch( setUserSettings( userSettings ) );
  };
}

export function changePassword( input ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    const params = {
      id: userSettings.id,
      user: {
        password: input.new_password,
        password_confirmation: input.confirm_new_password
      }
    };
    // send an update request immediately to change the password. Use
    // same_origin: true to ensure rails will update the users' session
    // with the password change flash message
    return inatjs.users.update( params, { same_origin: true } )
      .then( ( ) => {
        // redirect to the login page on success
        window.location = "/login";
      } )
      .catch( e => handleSaveError( e ).then( errors => {
        // catch errors such as validation errors so they can be displayed
        userSettings.errors = errors;
        dispatch( setUserSettings( userSettings, null ) );
      } ) );
  };
}

export function resendConfirmation( ) {
  return ( dispatch, getState ) => {
    const { userSettings } = getState( );
    return inatjs.users.resendConfirmation( { useAuth: true } ).then( ( ) => {
      dispatch( fetchUserSettings( SAVED ) );
      // If we go back to signing people out after sending the confirmation,
      // we will need to reload the window
      // window.location.reload( );
    } ).catch( e => {
      handleSaveError( e ).then( errors => {
        userSettings.errors = errors;
        dispatch( setUserSettings( userSettings, null ) );
      } );
    } );
  };
}

export function confirmResendConfirmation( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( setConfirmEmailModalState( {
      show: true,
      message: state.userSettings.email,
      type: "EmailConfirmation",
      confirmText: I18n.t( "send_confirmation_email" ),
      // If we want to go back to signing people out, this is the text we should use
      // confirmText: I18n.t( "send_and_sign_out", {
      //   defaultValue: I18n.t( "resend_and_sign_out" )
      // } ),
      onConfirm: async ( ) => {
        // Preemptively set confirmation_sent_at so the user sees a change
        // immediately
        await dispatch( setUserSettings( {
          ...getState( ).userSettings,
          confirmation_sent_at: ( new Date( ) ).toISOString( )
        } ) );
        await dispatch( postUserSettings( ) );
        const { userSettings } = getState( );
        if ( !userSettings.errors || userSettings.errors.length <= 0 ) {
          dispatch( resendConfirmation( ) );
        }
      }
    } ) );
  };
}

// Needs to update the user record which requires current state, as well as
// fetch those projects
export function addFavoriteProject( project ) {
  return function ( dispatch, getState ) {
    dispatch( updateUserData( {
      faved_project_ids: [...getState( ).userSettings.faved_project_ids, project.id]
    }, { savedStatus: NO_CHANGE } ) );
    return dispatch( fetchFavoriteProjects( ) );
  };
}
