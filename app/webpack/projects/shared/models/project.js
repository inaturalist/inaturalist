import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment-timezone";
import util from "../util";

const Project = class Project {
  constructor( attrs, additionalSearchParams = { } ) {
    Object.assign( this, attrs );
    this.is_traditional = this.project_type !== "collection" && this.project_type !== "umbrella";
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
      ttl: 900,
      v: moment( this.updated_at ).format( "x" )
    };
    if ( this.is_traditional ) {
      this.search_params.collection_preview = true;
    }
    Object.assign( this.search_params, additionalSearchParams );
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
        this.durationToEvent = moment.duration( this.startDate.diff( now ) );
      } else if ( this.startDate.isBefore( now ) ) {
        this.started = true;
      } else {
        this.durationToEvent = moment.duration( this.startDate.diff( now ) );
      }
    }
    if ( this.endDate ) {
      this.ended = util.isDate( end )
        ? this.endDate.isBefore( now, "day" )
        : this.endDate.isBefore( now );
    }
    this.undestroyedAdmins = _.filter( this.admins, a => !a._destroy );
    // TODO don't hardcode default color
    this.banner_color = this.banner_color || "#74ac00";
    this.errors = this.errors || { };
  }

  hasInsufficientRequirements( ) {
    let empty = true;
    const dateType = this.date_type;
    if ( !_.isEmpty( this.rule_term_id ) ) { empty = false; }
    if ( !_.isEmpty( this.rule_term_value_id ) ) { empty = false; }
    if ( dateType === "exact" && !_.isEmpty( this.rule_observed_on ) ) { empty = false; }
    if ( dateType === "range" && !_.isEmpty( this.rule_d1 ) ) { empty = false; }
    if ( dateType === "range" && !_.isEmpty( this.rule_d2 ) ) { empty = false; }
    // there are months, but not ALL months
    if ( dateType === "months" && !_.isEmpty( this.rule_month )
      && this.rule_month !== _.range( 1, 13 ).join( "," ) ) {
      empty = false;
    }

    if ( !_.isEmpty( this.project_observation_rules ) ) { empty = false; }
    if ( this.rule_members_only ) { empty = false; }
    return empty;
  }

  requirementsChangedFrom( otherProject ) {
    const trustChanged = this.prefers_user_trust !== otherProject.prefers_user_trust;
    // Rules are weird and can have other stuff packed into them like taxon and
    // place objects, so I'm using _.pick here to make sure we're only comparing
    // properties that might actually change. Realistically, the only things
    // that matter are length of the rules array (adding rules) and the value of
    // the _destroy attribute (removing rules)
    const changeableProperties = ["id", "operand_id", "operand_type", "operator", "_destroy"];
    const rulesChanged = !_.isEqual(
      _.map( this.project_observation_rules, rule => _.pick( rule, changeableProperties ) ),
      _.map( otherProject.project_observation_rules, rule => _.pick( rule, changeableProperties ) )
    );
    const prefsChanged = !_.isEqual( this.rule_preferences, otherProject.rule_preferences );
    return trustChanged || rulesChanged || prefsChanged;
  }

  bannerURL( ) {
    if ( this.droppedBanner ) {
      return this.droppedBanner.preview;
    }
    if ( this.customBanner( ) ) {
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
    }
    if ( this.customIcon( ) ) {
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
    this.notTaxonRules = [];
    this.userRules = [];
    this.notUserRules = [];
    this.placeRules = [];
    this.notPlaceRules = [];
    this.projectRules = [];
    _.each( this.project_observation_rules, rule => {
      if ( !rule._destroy ) {
        if ( rule.operand_type === "Taxon" && rule.operator === "not_in_taxon?" ) {
          this.notTaxonRules.push( rule );
        } else if ( rule.operand_type === "Taxon" ) {
          this.taxonRules.push( rule );
        } else if ( rule.operand_type === "User" && rule.operator === "not_observed_by_user?" ) {
          this.notUserRules.push( rule );
        } else if ( rule.operand_type === "User" ) {
          this.userRules.push( rule );
        } else if ( rule.operand_type === "Place" && rule.operator === "not_observed_in_place?" ) {
          this.notPlaceRules.push( rule );
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
      if ( pref.controlled_term ) {
        this[`rule_${pref.field}_instance`] = pref.controlled_term;
      }
    } );
    this.rule_quality_grade = this.rule_quality_grade || { };
  }

  setPreviewSearchParams( ) {
    this.previewSearchParamsObject = { };
    if ( this.is_umbrella ) {
      if ( !_.isEmpty( this.projectRules ) ) {
        this.previewSearchParamsObject.project_id = _.map(
          this.projectRules,
          r => r.operand_id
        ).join( "," );
      }
    } else {
      this.previewSearchParamsObject = _.fromPairs(
        _.map( _.filter( this.rule_preferences, p => p.value !== null ), p => [p.field, p.value] )
      );
      if ( !_.isEmpty( this.notTaxonRules ) ) {
        this.previewSearchParamsObject.without_taxon_id = _.map(
          this.notTaxonRules,
          r => r.operand_id
        ).join( "," );
      }
      if ( !_.isEmpty( this.taxonRules ) ) {
        this.previewSearchParamsObject.taxon_ids = _.map(
          this.taxonRules,
          r => r.operand_id
        ).join( "," );
      }
      if ( !_.isEmpty( this.notPlaceRules ) ) {
        this.previewSearchParamsObject.not_in_place = _.map(
          this.notPlaceRules,
          r => r.operand_id
        ).join( "," );
      }
      if ( !_.isEmpty( this.placeRules ) ) {
        this.previewSearchParamsObject.place_id = _.map(
          this.placeRules,
          r => r.operand_id
        ).join( "," );
      }
      if ( !_.isEmpty( this.notUserRules ) ) {
        this.previewSearchParamsObject.not_user_id = _.map(
          this.notUserRules,
          r => r.operand_id
        ).join( "," );
      }
      if ( !_.isEmpty( this.userRules ) ) {
        this.previewSearchParamsObject.user_id = _.map(
          this.userRules,
          r => r.operand_id
        ).join( "," );
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
    if ( this.previewSearchParamsObject.members_only ) {
      if ( this.id ) {
        this.previewSearchParamsObject.members_of_project = this.id;
      } else if ( this.previewSearchParamsObject.user_id ) {
        this.previewSearchParamsObject.user_id = _.intersection(
          _.map( this.admins, a => a.user.id ),
          _.map( ( this.previewSearchParamsObject.user_id || "" ).split( "," ), Number )
        ).join( "," );
        if ( _.isEmpty( this.previewSearchParamsObject.user_id ) ) {
          this.previewSearchParamsObject.user_id = "-1";
        }
      } else {
        this.previewSearchParamsObject.user_id = _.map( this.admins, a => a.user.id ).join( "," );
      }
      delete this.previewSearchParamsObject.members_only;
    }
    // using naming consistent with the web obs search form
    this.previewSearchParamsObject.verifiable = "any";
    this.previewSearchParamsObject.place_id = this.previewSearchParamsObject.place_id || "any";
    // Convert dates into iso8601 strings
    _.each( ["d1", "d2"], dateAttr => {
      if ( this.previewSearchParamsObject[dateAttr] ) {
        const d = moment( this.previewSearchParamsObject[dateAttr] );
        this.previewSearchParamsObject[dateAttr] = d.format( );
      }
    } );
    this.previewSearchParamsString = $.param( this.previewSearchParamsObject );
  }
};

export default Project;
