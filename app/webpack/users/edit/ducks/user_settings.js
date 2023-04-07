import inatjs from "inaturalistjs";
import _ from "lodash";
import { fetchRelationships, updateBlockedAndMutedUsers } from "./relationships";
import { setConfirmModalState } from "../../../observations/show/ducks/confirm_modal";
import { fetchNetworkSites } from "./network_sites";

const SET_USER_DATA = "user/edit/SET_USER_DATA";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_USER_DATA:
      return { ...action.userData };
    default:
  }
  return state;
}

export function setUserData( userData, savedStatus = "unsaved" ) {
  userData.saved_status = savedStatus;

  return {
    type: SET_USER_DATA,
    userData
  };
}

export function fetchUserSettings( savedStatus, relationshipsPage ) {
  return ( dispatch, getState ) => {
    const { profile, config } = getState( );
    const params = { useAuth: true };
    if ( config.testingApiV2 ) {
      params.fields = "all";
    }
    const initialLoad = _.isEmpty( profile );
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
        "universal_search_rank"
      ];

      const userSettings = Object.keys( results[0] ).reduce( ( object, key ) => {
        if ( !keysToIgnore.includes( key ) ) {
          object[key] = results[0][key];
        }
        return object;
      }, {} );

      dispatch( setUserData( userSettings, savedStatus ) );

      if ( initialLoad ) {
        dispatch( fetchRelationships( true ) );
      }
      if ( relationshipsPage ) {
        dispatch( updateBlockedAndMutedUsers( ) );
      }

      const { sites } = getState( );
      // If the user is affiliated with a site we don't know about, try fetching
      // the sites again
      if ( sites && sites.sites && userSettings.site_id ) {
        const siteIds = sites.sites.map( s => s.id );
        if ( siteIds.indexOf( userSettings.site_id ) < 0 ) {
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
  if ( body && body.errors && Array.isArray( body.errors ) && _.isObject( body.errors[0] )
    && body.errors[0].from === "externalAPI" && body.errors[0].message ) {
    // apiv2 passes on errors from rails in an object, e.g.:
    //   { errors: [{ from: "externalAPI", message: "**JSON encoded errors object**"}] }
    return JSON.parse( body.errors[0].message ).errors;
  }
  return body.errors ? body.errors : body.error.original.errors;
}

export function saveUserSettings( ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    const { id } = profile;

    const params = {
      id,
      user: { ...profile }
    };

    const topLevelAttributes = [
      "icon_delete"
    ];

    // move these attributes so they're nested under params, not params.user
    topLevelAttributes.forEach( attr => {
      if ( !profile[attr] ) return;

      params[attr] = true;
      delete params.user[attr];
    } );

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
    delete params.user.taxon_name_preferences;
    delete params.user.privileges;
    delete params.user.roles;
    delete params.user.saved_status;
    delete params.user.site;
    delete params.user.unconfirmed_email;
    delete params.user.updated_at;

    // fetching user settings here to get the source of truth
    // currently users.me returns different results than
    // dispatching setUserData( results[0] ) from users.update response
    return inatjs.users.update( params, { useAuth: true } )
      .then( ( ) => dispatch( fetchUserSettings( "saved" ) ) )
      .catch( e => handleSaveError( e ).then( errors => {
        profile.errors = errors;
        dispatch( setUserData( profile, null ) );
      } ) );
  };
}

export function handleCheckboxChange( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );

    if ( e.target.name === "prefers_no_email" ) {
      profile[e.target.name] = !e.target.checked;
    } else {
      profile[e.target.name] = e.target.checked;
    }
    dispatch( setUserData( profile ) );
  };
}

export function handleDisplayNames( { target } ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    const { value } = target;

    if ( value === "prefers_common_names" ) {
      profile.prefers_common_names = true;
      profile.prefers_scientific_name_first = false;
    } else if ( value === "prefers_scientific_name_first" ) {
      profile.prefers_common_names = true;
      profile.prefers_scientific_name_first = true;
    } else {
      profile.prefers_common_names = false;
      profile.prefers_scientific_name_first = false;
    }
    dispatch( setUserData( profile ) );
  };
}

export function handleInputChange( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile[e.target.name] = e.target.value;
    dispatch( setUserData( profile ) );
  };
}

export function handleCustomDropdownSelect( eventKey, name ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile[name] = eventKey;
    dispatch( setUserData( profile ) );
  };
}

export function handlePlaceAutocomplete( { item }, name ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );

    if ( profile[name] === null && item.id === 0 ) {
      // do nothing if the afterClear is triggered when the place input field starts empty
      // this ensures save settings button shows correctly
      return;
    }

    profile[name] = item.id;
    dispatch( setUserData( profile ) );
  };
}

export function handlePhotoUpload( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile.icon = e.target.files[0];
    dispatch( setUserData( profile ) );
  };
}

export function onFileDrop( droppedFiles ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );

    if ( _.isEmpty( droppedFiles ) ) { return; }
    const droppedFile = droppedFiles[0];
    if ( droppedFile.type.match( /^image\// ) ) {
      profile.icon = droppedFile;
      dispatch( setUserData( profile ) );
    }
  };
}

export function removePhoto( ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile.icon = null;
    profile.icon_url = null;
    profile.icon_delete = true;
    dispatch( setUserData( profile ) );
  };
}

export function changePassword( input ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    const params = {
      id: profile.id,
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
        profile.errors = errors;
        dispatch( setUserData( profile, null ) );
      } ) );
  };
}

export function resendConfirmation( ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile.confirmation_sent_at = ( new Date( ) ).toISOString( );
    dispatch( setUserData( profile ) );
    return inatjs.users.resendConfirmation( { useAuth: true } ).then( ( ) => {
      dispatch( fetchUserSettings( "saved" ) );
      // If we go back to signing people out after sending the confirmation,
      // we will need to reload the window
      // window.location.reload( );
    } ).catch( e => {
      handleSaveError( e ).then( errors => {
        profile.errors = errors;
        dispatch( setUserData( profile, null ) );
      } );
    } );
  };
}

export function confirmResendConfirmation( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "users_edit_send_confirmation_prompt_with_grace_html", {
        email: state.profile.email || ""
      } ),
      confirmText: I18n.t( "send_confirmation_email" ),
      // If we want to go back to signing people out, this is the text we should use
      // confirmText: I18n.t( "send_and_sign_out", {
      //   defaultValue: I18n.t( "resend_and_sign_out" )
      // } ),
      onConfirm: async ( ) => {
        await dispatch( saveUserSettings( ) );
        const { profile } = getState( );
        if ( !profile.errors || profile.errors.length <= 0 ) {
          dispatch( resendConfirmation( ) );
        }
      }
    } ) );
  };
}
