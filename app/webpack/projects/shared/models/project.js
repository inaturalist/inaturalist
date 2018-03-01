import _ from "lodash";
import inatjs from "inaturalistjs";

const Project = class Project {
  constructor( attrs ) {
    Object.assign( this, attrs );
    this.is_umbrella = ( this.collection_type === "umbrella" );
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
    this.search_params = { project_id: this.id, ttl: 300 };
    // TODO don't hardcode default color
    this.banner_color = this.banner_color || "#28387d";
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

};

export default Project;
