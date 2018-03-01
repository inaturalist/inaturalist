import _ from "lodash";
import inatjs from "inaturalistjs";
import Project from "../shared/models/project";

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

export function setProject( p ) {
  return setAttributes( { project: new Project( p ) } );
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

export function addProjectRule( operator, operandType, operand ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !operand ) { return; }
    const operandID = operandType ? operand.id : operand;
    let ruleExists = false;
    _.each( project.project_observation_rules, rule => {
      if ( operator === rule.operator &&
           operandType === rule.operand_type &&
           operandID === rule.operand_id ) {
        ruleExists = true;
      }
    } );
    if ( ruleExists ) { return; }
    const newRule = {
      operator,
      operand_type: operandType,
      operand_id: operandID
    };
    if ( operandType ) {
      const instanceName = operandType.toLowerCase( );
      newRule[instanceName] = operand;
    }
    project.project_observation_rules.push( newRule );
    dispatch( updateProject( { project_observation_rules: project.project_observation_rules } ) );
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

export function setRulePreference( field, value ) {
  return ( dispatch, getState ) => {
    const project = getState( ).form.project;
    if ( !project || !field ) { return; }
    project.rule_preferences = _.reject( project.rule_preferences, pref => pref.field === field );
    project.rule_preferences.push( { field, value } );
    dispatch( updateProject( { rule_preferences: project.rule_preferences } ) );
  };
}

export function showError( e ) {
  return dispatch => {
    if ( e.response ) {
      e.response.text( ).then( text => ( text ? JSON.parse( text ) : text ) ).then( json => {
        alert( json.error.original.error.join( ", " ) );
      } );
    } else {
      alert( e );
    }
    dispatch( updateProject( { saving: false } ) );
  };
}

export function submitProject( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const project = state.form.project;
    if ( !loggedIn( state ) || !project ) { return; }
    const payload = { project: {
      project_type: ( project.project_type === "umbrella" ) ? "umbrella" : "collection",
      user_id: state.config.currentUser.id,
      title: project.title,
      icon: project.droppedIcon ? project.droppedIcon : null,
      cover: project.droppedBanner ? project.droppedBanner : null,
      preferred_banner_color: project.banner_color,
      prefers_hide_title: project.hide_title,
      prefers_rule_quality_grade: project.rule_quality_grade ?
        _.keys( project.rule_quality_grade ).join( "," ) : "",
      prefers_rule_photos: _.isEmpty( project.rule_photos ) ? "" : project.rule_photos,
      prefers_rule_sounds: _.isEmpty( project.rule_sounds ) ? "" : project.rule_sounds,
      prefers_rule_observed_on:
        _.isEmpty( project.rule_observed_on ) ? "" : project.rule_observed_on,
      prefers_rule_d1: _.isEmpty( project.rule_d1 ) ? "" : project.rule_d1,
      prefers_rule_d2: _.isEmpty( project.rule_d2 ) ? "" : project.rule_d2
    } };
    if ( !payload.project.icon && project.iconDeleted ) {
      payload.icon_delete = true;
    }
    if ( !payload.project.cover && project.bannerDeleted ) {
      payload.cover_delete = true;
    }
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
