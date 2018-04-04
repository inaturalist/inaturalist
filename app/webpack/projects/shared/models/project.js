import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment-timezone";
import util from "../util";

const Project = class Project {
  constructor( attrs ) {
    Object.assign( this, attrs );
    this.is_umbrella = ( this.project_type === "umbrella" );
    this.project_observation_rules = this.project_observation_rules || [];
    const mappings = {
      Taxon: inatjs.Taxon,
      User: inatjs.User,
      Place: inatjs.Place,
      Project: inatjs.Project
    };
    // create inatjs model instances to use things like taxon photo helpers
    this.project_observation_rules = _.map( this.project_observation_rules, rule => {
      if ( rule.operand_type && mappings[rule.operand_type] ) {
        const MappedClass = mappings[rule.operand_type];
        const attr = MappedClass.name.toLowerCase( );
        if ( rule[attr] ) {
          return Object.assign( { }, rule, { [attr]: new MappedClass( rule[attr] ) } );
        }
      }
      return rule;
    } );
    this.createSpecificRuleAttributes( );
    this.createRulePreferenceAttributes( );
    this.search_params = {
      project_id: this.id,
      ttl: 600,
      v: moment( this.updated_at ).format( "x" )
    };
    this.setPreviewSearchParams( );
    const start = this.rule_observed_on || this.rule_d1;
    const end = this.rule_observed_on || this.rule_d2;
    this.startDate = util.momentDateFromString( start );
    this.endDate = util.momentDateFromString( end );
    this.started = false;
    this.ended = false;
    this.durationToEvent = null;
    const now = moment( );
    if ( this.startDate ) {
      if ( util.isDate( start ) ) {
        this.started = this.startDate.isSame( now, "day" ) || this.startDate.isBefore( now, "day" );
      } else {
        if ( this.startDate.isBefore( now ) ) {
          this.started = true;
        } else {
          this.durationToEvent = moment.duration( this.startDate.diff( now ) );
        }
      }
    }
    if ( this.endDate ) {
      this.ended = util.isDate( end ) ?
        this.endDate.isBefore( now, "day" ) :
        this.endDate.isBefore( now );
    }
    this.undestroyedAdmins = _.filter( this.admins, a => !a._destroy );
    // TODO don't hardcode default color
    this.banner_color = this.banner_color || "#28387d";
    this.errors = this.errors || { };
  }

  bannerURL( ) {
    if ( this.droppedBanner ) {
      return this.droppedBanner.preview;
    } else if ( this.customBanner( ) ) {
      return this.header_image_url;
    }
    return null;
  }

  customBanner( ) {
    return !_.isEmpty( this.header_image_url ) && !this.bannerDeleted;
  }

  iconURL( ) {
    if ( this.droppedIcon ) {
      return this.droppedIcon.preview;
    } else if ( this.customIcon( ) ) {
      return this.icon;
    }
    return null;
  }

  customIcon( ) {
    return this.icon && !this.icon.match( "attachment_defaults" ) && !this.iconDeleted;
  }

  // creates convenience instances used in project form components
  createSpecificRuleAttributes( ) {
    this.taxonRules = [];
    this.userRules = [];
    this.placeRules = [];
    this.projectRules = [];
    _.each( this.project_observation_rules, rule => {
      if ( !rule._destroy ) {
        if ( rule.operand_type === "Taxon" ) {
          this.taxonRules.push( rule );
        } else if ( rule.operand_type === "User" ) {
          this.userRules.push( rule );
        } else if ( rule.operand_type === "Place" ) {
          this.placeRules.push( rule );
        } else if ( rule.operand_type === "Project" ) {
          this.projectRules.push( rule );
        }
      }
    } );
  }

  // creates convenience instances used in project form components
  createRulePreferenceAttributes( ) {
    _.each( this.rule_preferences, pref => {
      this[`rule_${pref.field}`] = _.toString( pref.value );
      if ( pref.value && pref.field === "quality_grade" ) {
        this[`rule_${pref.field}`] = _.keyBy( pref.value.split( "," ) );
      }
    } );
    this.rule_quality_grade = this.rule_quality_grade || { };
  }

  setPreviewSearchParams( ) {
    this.previewSearchParamsObject = { };
    if ( this.is_umbrella ) {
      if ( !_.isEmpty( this.projectRules ) ) {
        this.previewSearchParamsObject.project_id =
          _.map( this.projectRules, r => r.operand_id ).join( "," );
      }
    } else {
      this.previewSearchParamsObject = _.fromPairs(
        _.map( _.filter( this.rule_preferences, p => p.value !== null ), p => [p.field, p.value] )
      );
      if ( !_.isEmpty( this.taxonRules ) ) {
        this.previewSearchParamsObject.taxon_id =
          _.map( this.taxonRules, r => r.operand_id ).join( "," );
      }
      if ( !_.isEmpty( this.placeRules ) ) {
        this.previewSearchParamsObject.place_id =
          _.map( this.placeRules, r => r.operand_id ).join( "," );
      }
      if ( !_.isEmpty( this.userRules ) ) {
        this.previewSearchParamsObject.user_id =
          _.map( this.userRules, r => r.operand_id ).join( "," );
      }
    }
    if ( !this.date_type ) {
      if ( this.previewSearchParamsObject.d1 || this.previewSearchParamsObject.d2 ) {
        this.date_type = "range";
      } else if ( this.previewSearchParamsObject.observed_on ) {
        this.date_type = "exact";
      } else if ( this.previewSearchParamsObject.month ) {
        this.date_type = "months";
      } else {
        this.date_type = "any";
      }
    }
    if ( this.date_type !== "range" ) {
      delete this.previewSearchParamsObject.d1;
      delete this.previewSearchParamsObject.d2;
    }
    if ( this.date_type !== "months" ) {
      delete this.previewSearchParamsObject.month;
    }
    if ( this.date_type !== "exact" ) {
      delete this.previewSearchParamsObject.observed_on;
    }
    // using naming consistent with the web obs search form
    if ( this.previewSearchParamsObject.observed_on ) {
      this.previewSearchParamsObject.on = this.previewSearchParamsObject.observed_on;
      delete this.previewSearchParamsObject.observed_on;
    }
    this.previewSearchParamsObject.verifiable = "any";
    this.previewSearchParamsObject.place_id = this.previewSearchParamsObject.place_id || "any";
    this.previewSearchParamsString = $.param( this.previewSearchParamsObject );
  }

};

export default Project;
