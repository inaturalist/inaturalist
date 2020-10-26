import inatjs from "inaturalistjs";
import _ from "lodash";

const SET_USER_DATA = "user/edit/SET_USER_DATA";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_USER_DATA:
      return { ...action.userData };
    default:
  }
  return state;
}

export function setUserData( userData, unsavedChanges = true ) {
  userData.unsaved_changes = unsavedChanges;

  return {
    type: SET_USER_DATA,
    userData
  };
}

export function fetchUserSettings( ) {
  return dispatch => inatjs.users.me( { useAuth: true } ).then( ( { results } ) => {
    // this is kind of unnecessary, but removing these since they're read-only keys
    // and don't need to be included in UI or users.update
    const keysToIgnore = [
      "spam", "suspended", "created_at", "login_autocomplete", "login_exact",
      "name_autocomplete", "observations_count", "identifications_count", "journal_posts_count",
      "activity_count", "species_count", "universal_search_rank", "prefers_automatic_taxon_changes"
    ];

    const userSettings = Object.keys( results[0] ).reduce( ( object, key ) => {
      if ( !keysToIgnore.includes( key ) ) {
        object[key] = results[0][key];
      }
      return object;
    }, {} );

    // console.log( userSettings, "profile from users.me" );

    dispatch( setUserData( userSettings, false ) );
  } ).catch( e => console.log( `Failed to fetch via users.me: ${e}` ) );
}

export function saveUserSettings( ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    const { id } = profile;

    const params = {
      id,
      user: profile
    };

    const updateOnlyAttributes = [
      "icon_delete",
      "make_observation_licenses_same",
      "make_photo_licenses_same",
      "make_sound_licenses_same",
      "upsaved_changes"
    ];

    // move these attributes so they're nested under params, not params.user
    updateOnlyAttributes.forEach( attr => {
      if ( !profile[attr] ) return;

      params[attr] = true;
      delete params.user[attr];
    } );

    // don't include the icon value from users.me, otherwise, will get a 500 error
    if ( typeof params.user.icon === "string" ) {
      delete params.user.icon;
    }

    // could leave these, but they're unpermitted parameters
    delete params.user.id;
    delete params.user.updated_at;

    return inatjs.users.update( params, { useAuth: true } ).then( ( ) => {
      // fetching user settings here to get the source of truth
      // currently users.me returns different results than
      // dispatching setUserData( results[0] ) from users.update response
      fetchUserSettings( );
    } ).catch( e => console.log( `Failed to update via users.update: ${e}` ) );
  };
}

export function handleCheckboxChange( e ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile[e.target.name] = e.target.checked;
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
    profile.icon_delete = true;
    dispatch( setUserData( profile ) );
  };
}

export function changePassword( input ) {
  return ( dispatch, getState ) => {
    const { profile } = getState( );
    profile.password = input.new_password;
    profile.password_confirmation = input.confirm_new_password;
    dispatch( setUserData( profile ) );
  };
}
