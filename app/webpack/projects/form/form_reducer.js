import _ from "lodash";
import inatjs from "inaturalistjs";
import Project from "../shared/models/project";
import { setConfirmModalState } from "../../observations/show/ducks/confirm_modal";

const SET_ATTRIBUTES = "projects-form/project/SET_ATTRIBUTES";
const UMBRELLA_SUBPROJECT_LIMIT = 500;

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
  p.initialSubprojectCount = _.isEmpty( p.project_observation_rules ) ? 0
    : _.filter( p.project_observation_rules, rule => rule.operand_type === "Project" ).length;
  const project = new Project( p );
  return setAttributes( { project, initialProject: _.cloneDeep( project ) } );
}

export function updateProject( attrs ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    return dispatch( setAttributes( {
      project: new Project( Object.assign( { }, state.form.project, attrs ) )
    } ) );
  };
}

export function addManager( user ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
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

export function setProjectError( field, error ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
    dispatch( updateProject( {
      errors: Object.assign( { }, project.errors, { [field]: error } )
    } ) );
  };
}

export function createNewProject( type, copyProject ) {
  return ( dispatch, getState ) => {
    const { config } = getState( );
    const newProjectAttributes = {
      project_type: type,
      user_id: config.currentUser.id,
      admins: [{ user: config.currentUser, role: "manager" }],
      rule_quality_grade: { research: true, needs_id: true }
    };
    if ( copyProject ) {
      const attributesToInherit = [
        "hide_umbrella_map_flags",
        "project_observation_rules",
        "rule_preferences",
        "search_parameters",
        "banner_color",
        "description",
        "title"
      ];
      _.each( attributesToInherit, a => { newProjectAttributes[a] = copyProject[a]; } );
      _.each( newProjectAttributes.project_observation_rules, r => delete r.id );
    }
    dispatch( setProject( newProjectAttributes ) );
    if ( copyProject ) {
      _.each( copyProject.admins, a => {
        dispatch( addManager( a.user ) );
      } );
      dispatch( setProjectError( "title", I18n.t( "views.projects.new.errors.name_already_taken" ) ) );
    }
    $( window ).scrollTop( 0 );
  };
}

export function setCopyProject( p ) {
  setAttributes( { copy_project: new Project( p ) } );
  return createNewProject( p.project_type, p );
}

export function loggedIn( state ) {
  return ( state && state.config && state.config.currentUser );
}

let titleValidationTimestamp = new Date( ).getTime( );
export function validateProjectTitle( ) {
  return ( dispatch, getState ) => {
    titleValidationTimestamp = new Date( ).getTime( );
    const { project } = getState( ).form;
    if ( !project ) { return null; }
    if ( _.isEmpty( project.title ) ) {
      dispatch( setProjectError( "title", I18n.t( "views.projects.new.errors.name_is_required" ) ) );
      return null;
    }
    if ( project.title.length > 100 ) {
      dispatch( setProjectError( "title", I18n.t( "views.projects.new.errors.summary_is_required" ) ) );
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
            dispatch( setProjectError( "title", I18n.t( "views.projects.new.errors.name_already_taken" ) ) );
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

export function validateSubprojects( ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
    if ( !project ) { return void null; }
    const subprojectLimit = (
      project.initialSubprojectCount && project.initialSubprojectCount > UMBRELLA_SUBPROJECT_LIMIT
    ) ? project.initialSubprojectCount : UMBRELLA_SUBPROJECT_LIMIT;
    const countActiveSubprojects = _.filter(
      project.project_observation_rules, rule => rule.operand_type === "Project" && !rule._destroy
    ).length;
    if ( countActiveSubprojects > subprojectLimit ) {
      dispatch( setProjectError( "subprojects",
        I18n.t( "views.projects.new.errors.cannot_have_more_than_x_project_rules",
          { x: subprojectLimit } ) ) );
      return void null;
    }
    dispatch( setProjectError( "subprojects", null ) );
  };
}

export function addProjectRule( operator, operandType, operand ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
    if ( !project || !operand ) { return; }
    const operandID = operandType ? operand.id : operand;


    const newRules = [];
    let ruleExists = false;
    _.each( project.project_observation_rules, rule => {
      const isMatch = (
        operator === rule.operator
        && operandType === rule.operand_type
        && operandID === rule.operand_id
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
    if ( operandType === "Project" ) {
      dispatch( validateSubprojects( ) );
    }
  };
}

export function removeProjectRule( ruleToRemove ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
    if ( !project || !ruleToRemove ) { return; }
    const newRules = [];
    _.each( project.project_observation_rules, rule => {
      if (
        ( ruleToRemove.id && rule.id && ruleToRemove.id === rule.id )
        || (
          ruleToRemove.operator === rule.operator
          && ruleToRemove.operand_type === rule.operand_type
          && ruleToRemove.operand_id === rule.operand_id
        )
      ) {
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
    if ( ruleToRemove.operand_type === "Project" ) {
      dispatch( validateSubprojects( ) );
    }
  };
}

export function removeProjectManager( projectUser ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
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
    const { project } = getState( ).form;
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
    const { project } = state.form;
    if ( !loggedIn( state ) || !project ) { return; }
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "views.projects.new.are_you_sure_you_want_to_delete" ),
      confirmText: I18n.t( "yes" ),
      onConfirm: ( ) => {
        setTimeout( ( ) => {
          dispatch( setConfirmModalState( {
            show: true,
            message: I18n.t( "deleting" ),
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
    const { project } = state.form;
    if ( !loggedIn( state ) || !project ) { return; }
    // check title and description which may not have been validated yet
    // if the user didn't enter text in those fields yet
    let errors;
    if ( _.isEmpty( project.title ) ) {
      dispatch( setProjectError( "title", I18n.t( "views.projects.new.errors.name_is_required" ) ) );
      errors = true;
    }
    if ( _.isEmpty( project.description ) ) {
      dispatch( setProjectError( "description",
        I18n.t( "views.projects.new.errors.summary_is_required" ) ) );
      errors = true;
    }
    if ( errors ) { return; }
    const payload = {
      project: {
        project_type: ( project.project_type === "umbrella" ) ? "umbrella" : "collection",
        user_id: project.user_id || state.config.currentUser.id,
        title: project.title,
        description: project.description,
        icon: project.droppedIcon ? project.droppedIcon : null,
        cover: project.droppedBanner ? project.droppedBanner : null,
        preferred_banner_color: project.banner_color,
        prefers_hide_title: !!project.hide_title,
        prefers_hide_umbrella_map_flags: !!project.hide_umbrella_map_flags,
        prefers_banner_contain: !!project.header_image_contain,
        prefers_rule_quality_grade: project.rule_quality_grade
          ? Object.keys( project.rule_quality_grade ).join( "," ) : "",
        prefers_rule_photos: _.isEmpty( project.rule_photos ) ? "" : project.rule_photos,
        prefers_rule_sounds: _.isEmpty( project.rule_sounds ) ? "" : project.rule_sounds,
        prefers_rule_term_id: _.isEmpty( project.rule_term_id ) ? "" : project.rule_term_id,
        prefers_rule_term_value_id:
          ( _.isEmpty( project.rule_term_value_id ) || _.isEmpty( project.rule_term_id ) )
            ? "" : project.rule_term_value_id,
        prefers_rule_observed_on:
          ( project.date_type !== "exact" || _.isEmpty( project.rule_observed_on ) )
            ? "" : project.rule_observed_on.trim( ),
        prefers_rule_d1: project.date_type !== "range" || _.isEmpty( project.rule_d1 )
          ? "" : project.rule_d1.trim( ),
        prefers_rule_d2: project.date_type !== "range" || _.isEmpty( project.rule_d2 )
          ? "" : project.rule_d2.trim( ),
        prefers_rule_month: project.date_type !== "months" || _.isEmpty( project.rule_month )
          || project.rule_month === _.range( 1, 13 ).join( "," ) ? "" : project.rule_month,
        prefers_rule_native: _.isEmpty( project.rule_native ) ? "" : project.rule_native,
        prefers_rule_introduced: _.isEmpty( project.rule_introduced ) ? "" : project.rule_introduced,
        prefers_rule_members_only: _.isEmpty( project.rule_members_only ) ? "" : project.rule_members_only,
        prefers_user_trust: project.prefers_user_trust === true
      }
    };
    if ( !payload.project.icon && project.iconDeleted ) {
      payload.icon_delete = true;
    }
    if ( !payload.project.cover && project.bannerDeleted ) {
      payload.cover_delete = true;
    }

    // add project_observation_rules
    payload.project.project_observation_rules_attributes = payload.project
      .project_observation_rules_attributes || [];
    _.each( project.project_observation_rules, rule => {
      if (
        ( project.project_type === "umbrella" && rule.operand_type === "Project" )
        || (
          project.project_type !== "umbrella"
          && (
            rule.operand_type === "Taxon"
            || rule.operand_type === "User"
            || rule.operand_type === "Place"
          )
        )
      ) {
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
    payload.project.admin_attributes = payload.project.admin_attributes || [];
    _.each( project.admins, admin => {
      const projectUserPayload = {
        user_id: admin.user.id,
        role: admin.role
      };
      if ( admin.id ) {
        projectUserPayload.id = admin.id;
        projectUserPayload._destroy = !!admin._destroy;
      }
      payload.project.admin_attributes.push( projectUserPayload );
    } );

    dispatch( updateProject( { saving: true } ) );
    if ( project.id ) {
      payload.id = project.slug;
      inatjs.projects.update( payload ).then( p => {
        window.location = `/projects/${p.slug}`;
      } ).catch( e => {
        dispatch( showError( e ) );
      } );
    } else {
      inatjs.projects.create( payload ).then( p => {
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
    const { project, initialProject } = state.form;
    if (
      project.id
      && project.prefers_user_trust
      && project.requirementsChangedFrom( initialProject )
    ) {
      dispatch( setConfirmModalState( {
        show: true,
        message: I18n.t( "views.projects.new.trusting_members_will_be_notified" ),
        confirmText: I18n.t( "ok" ),
        cancelText: I18n.t( "cancel" ),
        onConfirm: ( ) => {
          dispatch( submitProject( ) );
        }
      } ) );
      return;
    }
    if ( !project.hasInsufficientRequirements( ) ) {
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

export function duplicateProject( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { project } = state.form;
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "views.projects.new.are_you_ready_to_duplicate" ),
      confirmText: I18n.t( "yes" ),
      onConfirm: ( ) => {
        window.location = `/projects/new?copy_project_id=${project.slug}`;
      }
    } ) );
  };
}

export function changeOwner( projectUser ) {
  return ( dispatch, getState ) => {
    const { project } = getState( ).form;
    if ( !project || !projectUser ) { return; }
    if ( confirm( I18n.t( "views.projects.edit.change_owner_alert" ) ) ) {
      dispatch( updateProject( {
        user: projectUser.user,
        user_id: projectUser.user.id,
        saving: false
      } ) );
    }
  };
}
