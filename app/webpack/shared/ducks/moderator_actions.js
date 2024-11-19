import _ from "lodash";
import {
  Comment,
  Photo,
  Sound
} from "inaturalistjs";
import { fetch } from "../util";

const SHOW_MODERATOR_ACTION_FORM = "observations-shared/moderator_actions/show_moderator_action_form";
const HIDE_MODERATOR_ACTION_FORM = "observations-shared/moderator_actions/hide_moderator_action_form";

const moderatorActionReducer = ( state = {
  visible: false,
  item: null,
  action: "hide"
}, action ) => {
  if ( action.type === SHOW_MODERATOR_ACTION_FORM ) {
    state.visible = true;
    state.item = action.item;
    state.action = ( action.action === "unhide" ) ? "unhide" : "hide";
  } else if ( action.type === HIDE_MODERATOR_ACTION_FORM ) {
    state.visible = false;
  }
  return state;
};

const showModeratorActionForm = ( item, action ) => (
  {
    type: SHOW_MODERATOR_ACTION_FORM,
    item,
    action
  }
);

const submitModeratorAction = ( item, action, reason ) => (
  function ( ) {
    const data = new FormData( );
    data.append( "authenticity_token", $( "meta[name=csrf-token]" ).attr( "content" ) );
    const isID = !!item.taxon;
    if ( isID ) {
      data.append( "moderator_action[resource_type]", "Identification" );
    } else if ( item instanceof Comment ) {
      data.append( "moderator_action[resource_type]", "Comment" );
    } else if ( item instanceof Photo ) {
      data.append( "moderator_action[resource_type]", "Photo" );
    } else if ( item instanceof Sound ) {
      data.append( "moderator_action[resource_type]", "Sound" );
    } else {
      throw new Error( "Can't submit moderator action on an unknown type" );
    }
    data.append( "moderator_action[resource_id]", item.id );
    data.append( "moderator_action[reason]", reason );
    data.append( "moderator_action[action]", action );
    return fetch( "/moderator_actions.json", {
      method: "POST",
      body: data
    } ).then( response => {
      if ( response.status >= 400 ) {
        response.json( ).then( json => {
          let errorText = "Could not save moderator action";
          _.forEach( json.errors, ( v, k ) => {
            errorText += `\n${json.errors[k].map( error => `${k} ${error}` ).join( "\n" )}`;
          } );
          alert( errorText );
        } );
      }
    } ).catch( e => {
      alert( I18n.t( "doh_something_went_wrong_error", { error: e.message } ) );
    } );
  }
);

const hideModeratorActionForm = ( ) => ( {
  type: HIDE_MODERATOR_ACTION_FORM
} );

const revealHiddenContent = item => {
  if ( !( item instanceof Photo || item instanceof Sound ) ) {
    return null;
  }
  const relevantModeratorAction = _.first(
    _.orderBy( item.moderator_actions, ["created_at", "desc"] )
  );
  if ( !relevantModeratorAction ) {
    return null;
  }
  return ( ) => {
    // open a new window now in the context of the user action so it doesn't get popup-blocked
    const resourceWindow = window.open( );
    return fetch( `/moderator_actions/${relevantModeratorAction.id}/resource_url`, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": $( "meta[name=csrf-token]" ).attr( "content" )
      }
    } ).then( response => {
      if ( response.status === 200 ) {
        response.json( ).then( json => {
          if ( json && json.resource_url ) {
            // update the location of the already opened window
            resourceWindow.location = json.resource_url;
            resourceWindow.focus( );
          }
        } );
      }
    } ).catch( e => {
      alert( I18n.t( "doh_something_went_wrong_error", { error: e.message } ) );
    } );
  };
};

export default moderatorActionReducer;
export {
  showModeratorActionForm,
  hideModeratorActionForm,
  submitModeratorAction,
  revealHiddenContent
};
