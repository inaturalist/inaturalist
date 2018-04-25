import _ from "lodash";
import inatjs from "inaturalistjs";
import Project from "../shared/models/project";
import { setConfirmModalState } from "../../observations/show/ducks/confirm_modal";

const SET_ATTRIBUTES = "projects-form/project/SET_ATTRIBUTES";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
    default:
  }
  return state;
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function removeProject( ) {
  $( window ).scrollTop( 0 );
  return setAttributes( { project: null } );
}

export function setProject( p ) {
  return setAttributes( { project: new Project( p ) } );
}

export function createNewProject( type ) {
  return ( dispatch, getState ) => {
    const config = getState( ).config;
    dispatch( setProject( {
      project_type: type,
      user_id: config.currentUser.id,
      admins: [{ user: config.currentUser, role: "manager" }]
    } ) );
    $( window ).scrollTop( 0 );
  };
}

export function loggedIn( state ) {
  return ( state && state.config && state.config.currentUser );
}

export function updateProject( attrs ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    return dispatch( setAttributes( {
      project: new Project( Object.assign( { }, state.form.project, attrs ) )
    } ) );
  };
}

export function setProjectError( field, error ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    dispatch( updateProject( { errors:
      Object.assign( { }, project.errors, { [field]: error } )
    } ) );
  };
}

let titleValidationTimestamp = new Date( ).getTime( );
export function validateProjectTitle( ) {
  return ( dispatch, getState ) => {
    titleValidationTimestamp = new Date( ).getTime( );
    const project = getState( ).form.project;
    if ( !project ) { return null; }
    if ( _.isEmpty( project.title ) ) {
      dispatch( setProjectError( "title", "Project name is required" ) );
      return null;
    }
    if ( project.title.length > 100 ) {
      dispatch( setProjectError( "title", "Project name must be less than 100 characters" ) );
      return null;
    }
    const searchParams = { title_exact: project.title, not_id: project.id, per_page: 1 };
    const timecheck = _.clone( titleValidationTimestamp );
    dispatch( setProjectError( "title", null ) );
    return setTimeout( ( ) => {
      if ( timecheck === titleValidationTimestamp ) {
        inatjs.projects.autocomplete( searchParams ).then( response => {
          if ( _.isEmpty( response.results ) ) {
            dispatch( setProjectError( "title", null ) );
          } else {
            dispatch( setProjectError( "title", "Project name already taken" ) );
          }
        } ).catch( e => console.log( e ) );
      }
    }, 250 );
  };
}

export function setTitle( title ) {
  return dispatch => {
    dispatch( updateProject( { title } ) );
    dispatch( validateProjectTitle( ) );
  };
}

export function setDescription( description ) {
  return dispatch => {
    let descriptionError;
    if ( _.isEmpty( description ) ) {
      descriptionError = "Project summary text is required";
    }
    dispatch( updateProject( { description } ) );
    dispatch( setProjectError( "description", descriptionError ) );
  };
}

export function addProjectRule( operator, operandType, operand ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !operand ) { return; }
    const operandID = operandType ? operand.id : operand;


    const newRules = [];
    let ruleExists = false;
    _.each( project.project_observation_rules, rule => {
      const isMatch = (
        operator === rule.operator &&
        operandType === rule.operand_type &&
        operandID === rule.operand_id
      );
      if ( isMatch && rule._destroy ) {
        newRules.push( Object.assign( { }, rule, { _destroy: false } ) );
        ruleExists = true;
      } else {
        ruleExists = ruleExists || isMatch;
        newRules.push( rule );
      }
    } );
    if ( !ruleExists ) {
      const newRule = {
        operator,
        operand_type: operandType,
        operand_id: operandID
      };
      if ( operandType ) {
        const instanceName = operandType.toLowerCase( );
        newRule[instanceName] = operand;
      }
      newRules.push( newRule );
    }
    dispatch( updateProject( { project_observation_rules: newRules } ) );
  };
}

export function removeProjectRule( ruleToRemove ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !ruleToRemove ) { return; }
    const newRules = [];
    _.each( project.project_observation_rules, rule => {
      if ( ( ruleToRemove.id && rule.id && ruleToRemove.id === rule.id ) ||
           ( ruleToRemove.operator === rule.operator &&
             ruleToRemove.operand_type === rule.operand_type &&
             ruleToRemove.operand_id === rule.operand_id ) ) {
        // if the rule already exists in the database, mark it as to be destroyed
        // otherwise, just leave the rule off new rule list
        if ( rule.id ) {
          newRules.push( Object.assign( { }, rule, { _destroy: true } ) );
        }
      } else {
        newRules.push( rule );
      }
    } );
    dispatch( updateProject( { project_observation_rules: newRules } ) );
  };
}

export function addManager( user ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !user ) { return; }
    const newAdmins = [];
    let managerExists = false;
    _.each( project.admins, admin => {
      const isMatch = ( admin.user.id === user.id );
      if ( isMatch && admin._destroy ) {
        newAdmins.push( Object.assign( { }, admin, { _destroy: false } ) );
        managerExists = true;
      } else {
        managerExists = managerExists || isMatch;
        newAdmins.push( admin );
      }
    } );
    if ( !managerExists ) {
      newAdmins.push( { user, role: "manager" } );
    }
    dispatch( updateProject( { admins: newAdmins } ) );
  };
}

export function removeProjectUser( projectUser ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !projectUser ) { return; }
    const newAdmins = [];
    _.each( project.admins, admin => {
      if ( projectUser.id && admin.id && projectUser.id === admin.id ) {
        newAdmins.push( Object.assign( { }, admin, { _destroy: true } ) );
      } else if ( projectUser.user.id !== admin.user.id ) {
        newAdmins.push( admin );
      }
    } );
    dispatch( updateProject( { admins: newAdmins } ) );
  };
}

export function setRulePreference( field, value ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !field ) { return; }
    project.rule_preferences = _.reject( project.rule_preferences, pref => pref.field === field );
    project.rule_preferences.push( { field, value } );
    let dateType = project.date_type;
    if ( field === "observed_on" ) {
      dateType = "exact";
    } else if ( field === "d1" || field === "d2" ) {
      dateType = "range";
    } else if ( field === "month" ) {
      dateType = "months";
    }
    dispatch( updateProject( {
      rule_preferences: project.rule_preferences,
      date_type: dateType
    } ) );
  };
}

export function showError( e ) {
  return dispatch => {
    if ( e.response ) {
      e.response.text( ).then( text => ( text ? JSON.parse( text ) : text ) ).then( json => {
        console.log( json );
        alert( JSON.stringify( json.error.original ) );
      } );
    } else {
      alert( e );
    }
    dispatch( updateProject( { saving: false } ) );
  };
}


export function onFileDrop( droppedFiles, field ) {
  return dispatch => {
    if ( _.isEmpty( droppedFiles ) ) { return; }
    const droppedFile = droppedFiles[0];
    if ( droppedFile.type.match( /^image\// ) ) {
      dispatch( updateProject( {
        [field]: droppedFile
      } ) );
    }
  };
}

export function deleteProject( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const project = state.form.project;
    if ( !loggedIn( state ) || !project ) { return; }
    dispatch( setConfirmModalState( {
      show: true,
      message: "Are you sure you want to delete this project?",
      confirmText: I18n.t( "yes" ),
      onConfirm: ( ) => {
        setTimeout( ( ) => {
          dispatch( setConfirmModalState( {
            show: true,
            message: "Deleting...",
            hideFooter: true
          } ) );
        }, 1 );
        inatjs.projects.delete( { id: project.id } ).then( ( ) => {
          window.location = `/projects/user/${state.config.currentUser.login}`;
        } ).catch( e => {
          dispatch( showError( e ) );
        } );
      }
    } ) );
  };
}

export function submitProject( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const project = state.form.project;
    if ( !loggedIn( state ) || !project ) { return; }
    const viewerIsAdmin = state.config.currentUser.roles &&
      state.config.currentUser.roles.indexOf( "admin" ) >= 0;
    // check title and description which may not have been validated yet
    // if the user didn't enter text in those fields yet
    let errors;
    if ( _.isEmpty( project.title ) ) {
      dispatch( setProjectError( "title", "Project name is required" ) );
      errors = true;
    }
    if ( _.isEmpty( project.description ) ) {
      dispatch( setProjectError( "description", "Project summary text is required" ) );
      errors = true;
    }
    if ( errors ) { return; }
    const payload = { project: {
      project_type: ( project.project_type === "umbrella" ) ? "umbrella" : "collection",
      user_id: project.user_id || state.config.currentUser.id,
      title: project.title,
      description: project.description,
      icon: project.droppedIcon ? project.droppedIcon : null,
      cover: project.droppedBanner ? project.droppedBanner : null,
      preferred_banner_color: project.banner_color,
      prefers_hide_title: project.hide_title,
      prefers_rule_quality_grade: project.rule_quality_grade ?
        _.keys( project.rule_quality_grade ).join( "," ) : "",
      prefers_rule_photos: _.isEmpty( project.rule_photos ) ? "" : project.rule_photos,
      prefers_rule_sounds: _.isEmpty( project.rule_sounds ) ? "" : project.rule_sounds,
      prefers_rule_observed_on:
        ( project.date_type !== "exact" || _.isEmpty( project.rule_observed_on ) ) ?
          "" : project.rule_observed_on.trim( ),
      prefers_rule_d1: project.date_type !== "range" || _.isEmpty( project.rule_d1 ) ?
        "" : project.rule_d1.trim( ),
      prefers_rule_d2: project.date_type !== "range" || _.isEmpty( project.rule_d2 ) ?
        "" : project.rule_d2.trim( ),
      prefers_rule_month: project.date_type !== "months" || _.isEmpty( project.rule_month ) ?
        "" : project.rule_month
    } };
    if ( !payload.project.icon && project.iconDeleted ) {
      payload.icon_delete = true;
    }
    if ( !payload.project.cover && project.bannerDeleted ) {
      payload.cover_delete = true;
    }

    // add project_observation_rules
    payload.project.project_observation_rules_attributes =
      payload.project.project_observation_rules_attributes || [];
    _.each( project.project_observation_rules, rule => {
      if ( ( project.project_type === "umbrella" && rule.operand_type === "Project" ) ||
           ( project.project_type !== "umbrella" &&
             ( rule.operand_type === "Taxon" ||
               rule.operand_type === "User" ||
               rule.operand_type === "Place" ) ) ) {
        const rulePayload = {
          operator: rule.operator,
          operand_type: rule.operand_type,
          operand_id: rule.operand_id
        };
        if ( rule.id ) {
          rulePayload.id = rule.id;
          rulePayload._destroy = !!rule._destroy;
        }
        payload.project.project_observation_rules_attributes.push( rulePayload );
      }
    } );

    // add project_users
    payload.project.project_users_attributes =
      payload.project.project_users_attributes || [];
    _.each( project.admins, admin => {
      const projectUserPayload = {
        user_id: admin.user.id,
        role: admin.role
      };
      if ( admin.id ) {
        projectUserPayload.id = admin.id;
        projectUserPayload._destroy = !!admin._destroy;
      }
      payload.project.project_users_attributes.push( projectUserPayload );
    } );

    // add featured_at flag
    if ( viewerIsAdmin ) {
      payload.project.featured_at = project.featured_at ? "1" : null;
    }

    dispatch( updateProject( { saving: true } ) );
    if ( project.id ) {
      payload.id = project.slug;
      inatjs.projects.update( payload ).then( ( p ) => {
        window.location = `/projects/${p.slug}`;
      } ).catch( e => {
        dispatch( showError( e ) );
      } );
    } else {
      inatjs.projects.create( payload ).then( ( p ) => {
        window.location = `/projects/${p.slug}`;
      } ).catch( e => {
        dispatch( showError( e ) );
      } );
    }
  };
}

export function confirmSubmitProject( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const project = state.form.project;
    let empty = true;
    const dateType = project.date_type;
    if ( !_.isEmpty( project.rule_quality_grade ) ) { empty = false; }
    if ( !_.isEmpty( project.rule_photos ) ) { empty = false; }
    if ( !_.isEmpty( project.rule_sounds ) ) { empty = false; }
    if ( dateType === "exact" && !_.isEmpty( project.rule_observed_on ) ) { empty = false; }
    if ( dateType === "range" && !_.isEmpty( project.rule_d1 ) ) { empty = false; }
    if ( dateType === "range" && !_.isEmpty( project.rule_d2 ) ) { empty = false; }
    if ( dateType === "months" && !_.isEmpty( project.rule_month ) ) { empty = false; }
    if ( !_.isEmpty( project.project_observation_rules ) ) { empty = false; }
    if ( !empty ) {
      dispatch( submitProject( ) );
      return;
    }
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "views.projects.new.you_have_not_defined_any_observation_requirements" ),
      confirmText: I18n.t( "go_back" ),
      cancelText: I18n.t( "continue" ),
      onCancel: ( ) => {
        dispatch( submitProject( ) );
      }
    } ) );
  };
}
