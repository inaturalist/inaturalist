import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment-timezone";
import util from "../util";

const Project = class Project extends inatjs.Project {
  constructor( attrs, additionalSearchParams = { } ) {
    super( attrs );
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
          return { ...rule, [attr]: new MappedClass( rule[attr] ) };
        }
      }
      return rule;
    } );
    this.createSpecificRuleAttributes( );
    this.createRulePreferenceAttributes( );
    const updatedSecondsAgo = moment( ).diff( this.updated_at, "seconds" );
    this.search_params = {
      project_id: this.id,
      ttl: 900
    };
    if ( updatedSecondsAgo < 900 ) {
      // the project was recently updated. Add a parameter ?v to the query,
      // representing the value of updated_at, so results cached with
      // potentially old search parameters are not used
      this.search_params.v = moment( this.updated_at ).format( "x" );
    }
    if ( this.is_traditional ) {
      this.search_params.collection_preview = true;
    }
    Object.assign( this.search_params, additionalSearchParams );
    const start = this.rule_observed_on || this.rule_d1;
    const end = this.rule_observed_on || this.rule_d2;
    this.startDate = util.momentDateFromString( start );
    this.startDateIncludesTime = this.startDate && !util.isDate( start );
    this.endDate = util.momentDateFromString( end );
    this.endDateIncludesTime = this.endDate && !util.isDate( end );
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
    if ( !this.editing ) {
      return;
    }

    this.mapAttributesToFormDates( );
    this.errors = this.errors || { };
    this.validateNewDates( );
    this.setPreviewSearchParams( );
  }

  mapAttributesToFormDates( ) {
    // when projects are loaded from an API response, the way the form dates
    // should be set up depeneds on the nature of the response, particularly
    // when it comes to d1 and d2. Projects using d1 and d2 may use the
    // "exact" date type if they are the same day relative to the viewwer,
    // or they may use the "range" date type of they are different days
    if ( !this.date_type ) {
      if ( ( this.rule_d1 && this.startDate ) || ( this.rule_d2 && this.endDate ) ) {
        const startDay = this.startDate?.format( "YYYY-MM-DD" );
        const endDay = this.endDate?.format( "YYYY-MM-DD" );
        if ( startDay === endDay ) {
          this.date_type = "exact";
          this.includeExactTimes = true;
          this.exactDate = this.startDate.format( "YYYY-MM-DD" );
          this.exactDateD1 = this.startDate.format( "HH:mm UTCZ" );
          this.exactDateD2 = this.endDate.format( "HH:mm UTCZ" );
          return;
        }
        this.rangeStartDate = this.startDate?.format( "YYYY-MM-DD" );
        if ( this.startDateIncludesTime ) {
          this.rangeStartTime = this.startDate.format( "HH:mm UTCZ" );
          this.includeRangeTimes = true;
        }
        this.rangeEndDate = this.endDate?.format( "YYYY-MM-DD" );
        if ( this.endDateIncludesTime ) {
          this.rangeEndTime = this.endDate.format( "HH:mm UTCZ" );
          this.includeRangeTimes = true;
        }
        this.date_type = "range";
      } else if ( this.rule_observed_on ) {
        this.date_type = "exact";
        this.exactDate = this.rule_observed_on;
      } else if ( this.rule_month ) {
        this.date_type = "months";
      } else {
        this.date_type = "any";
      }
    }
  }

  validateExactTime( index ) {
    const exactAttribute = `exactDateD${index}`;
    const exactMomentAttribute = `exactDateD${index}Moment`;
    delete this.errors[exactAttribute];
    delete this[exactMomentAttribute];

    if ( _.isEmpty( this[exactAttribute] ) ) {
      return;
    }

    // combine the date and time and validate the resulting datetime
    const strippedTime = this[exactAttribute].replace( " UTC", "" );
    this[exactMomentAttribute] = moment(
      `${this.exactDate}T${strippedTime}`,
      "YYYY-MM-DDTHH:mmZ",
      true
    );
    if ( !this[exactMomentAttribute].isValid( ) ) {
      this.errors[exactAttribute] = I18n.t( "invalid_time" );
      return;
    }

    // if one time is set and the other is not, set it accordingly. Also mark it as being updated -
    // the datetimepicker will not recognize the updated time unless it is re-renderd, which we
    // only want to do when the time is force-updated
    let altIndex;
    let altMomentMethod;
    if ( index === 1 ) {
      altIndex = 2;
      altMomentMethod = "endOf";
    } else {
      altIndex = 1;
      altMomentMethod = "startOf";
    }
    const altExactAttribute = `exactDateD${altIndex}`;
    const altExactAttributeUpdatedAt = `exactDateD${altIndex}UpdatedAt`;
    const altExactMomentAttribute = `exactDateD${altIndex}Moment`;
    if ( _.isEmpty( this[altExactAttribute] ) ) {
      this[altExactMomentAttribute] = this[exactMomentAttribute].clone( )[altMomentMethod]( "day" );
      this[altExactAttribute] = this[altExactMomentAttribute].format( "HH:mm UTCZ" );
      this[altExactAttributeUpdatedAt] = Date.now( );
    }
  }

  validateExactDates( ) {
    if ( this.date_type !== "exact" ) {
      return;
    }

    if ( _.isEmpty( this.exactDate ) ) {
      delete this.exactDateD1;
      delete this.exactDateD2;
      this.exactDateD1UpdatedAt = Date.now( );
      this.exactDateD2UpdatedAt = Date.now( );
      return;
    }

    delete this.errors.exactDate;
    if ( !moment( this.exactDate.trim( ), "YYYY-MM-DD", true ).isValid( ) ) {
      this.errors.exactDate = I18n.t( "invalid_date" );
      return;
    }

    // validate the values in the time fields
    this.validateExactTime( 1 );
    this.validateExactTime( 2 );

    if ( this.exactDateD1 && this.exactDateD2
      && !this.errors.exactDateD1 && !this.errors.exactDateD2
    ) {
      if ( this.exactDateD2Moment.isSameOrBefore( this.exactDateD1Moment ) ) {
        this.errors.exactDateD2 = I18n.t( "views.projects.new.end_time_must_be_after_start_time" );
        return;
      }
      // if both times are valid, set tentative date range rules
      this.rule_d1 = this.exactDateD1Moment.format( "YYYY-MM-DD HH:mm Z" );
      this.rule_d2 = this.exactDateD2Moment.format( "YYYY-MM-DD HH:mm Z" );
      return;
    }

    // if both times aren't valid, only apply the date as a tentative rule
    this.rule_observed_on = this.exactDate;
  }

  validateRangeTime( type ) {
    const rangeTimeAttribute = `range${type}Time`;
    const rangeDateAttribute = `range${type}Date`;
    const rangeTimeMomentAttribute = `range${type}TimeMoment`;
    delete this.errors[rangeTimeAttribute];
    delete this[rangeTimeMomentAttribute];

    if ( _.isEmpty( this[rangeTimeAttribute] ) ) {
      return;
    }

    // combine the date and time and validate the resulting datetime
    const strippedTime = this[rangeTimeAttribute].replace( " UTC", "" );
    this[rangeTimeMomentAttribute] = moment(
      `${this[rangeDateAttribute]}T${strippedTime}`,
      "YYYY-MM-DDTHH:mmZ",
      true
    );
    if ( !this[rangeTimeMomentAttribute].isValid( ) ) {
      this.errors[rangeTimeAttribute] = I18n.t( "invalid_time" );
    }
  }

  validateRangeDates( ) {
    if ( this.date_type !== "range" ) {
      return;
    }

    delete this.errors.rangeStartDate;
    let rangeStartDateMoment;
    if ( _.isEmpty( this.rangeStartDate ) ) {
      delete this.rangeStartTime;
      this.rangeStartTimeUpdatedAt = Date.now( );
    } else {
      rangeStartDateMoment = moment( this.rangeStartDate.trim( ), "YYYY-MM-DD", true );
      if ( !rangeStartDateMoment.isValid( ) ) {
        this.errors.rangeStartDate = I18n.t( "invalid_date" );
      } else {
        this.validateRangeTime( "Start" );
      }
    }

    delete this.errors.rangeEndDate;
    let rangeEndDateMoment;
    if ( _.isEmpty( this.rangeEndDate ) ) {
      delete this.rangeEndTime;
      this.rangeEndTimeUpdatedAt = Date.now( );
    } else {
      rangeEndDateMoment = moment( this.rangeEndDate.trim( ), "YYYY-MM-DD", true );
      if ( !rangeEndDateMoment.isValid( ) ) {
        this.errors.rangeEndDate = I18n.t( "invalid_date" );
      } else {
        this.validateRangeTime( "End" );
      }
    }

    // validate the end date is after the start date
    if ( rangeEndDateMoment && rangeStartDateMoment
      && rangeEndDateMoment.isSameOrBefore( rangeStartDateMoment ) ) {
      this.errors.rangeEndDate = I18n.t( "views.projects.new.end_date_must_be_after_start_date" );
      return;
    }

    if ( this.rangeStartDate && !this.errors.rangeStartDate ) {
      if ( this.rangeStartTime && !this.errors.rangeStartTime ) {
        this.rule_d1 = this.rangeStartTimeMoment.format( "YYYY-MM-DD HH:mm Z" );
      } else {
        this.rule_d1 = this.rangeStartDate;
      }
    }
    if ( this.rangeEndDate && !this.errors.rangeEndDate ) {
      if ( this.rangeEndTime && !this.errors.rangeEndTime ) {
        this.rule_d2 = this.rangeEndTimeMoment.format( "YYYY-MM-DD HH:mm Z" );
      } else {
        this.rule_d2 = this.rangeEndDate;
      }
    }
  }

  validateNewDates( ) {
    delete this.rule_d1;
    delete this.rule_d2;
    delete this.rule_observed_on;
    this.validateExactDates( );
    this.validateRangeDates( );
  }

  hasInsufficientRequirements( ) {
    let empty = true;
    const dateType = this.date_type;
    if ( !_.isEmpty( this.rule_term_id ) ) { empty = false; }
    if ( !_.isEmpty( this.rule_term_value_id ) ) { empty = false; }
    if ( dateType !== "months" && (
      !_.isEmpty( this.rule_observed_on )
      || !_.isEmpty( this.rule_d1 )
      || !_.isEmpty( this.rule_d2 )
    ) ) { empty = false; }
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
    }
    if ( !this.is_umbrella || this.is_delegated_umbrella ) {
      this.previewSearchParamsObject = _.fromPairs(
        _.map(
          _.filter( this.rule_preferences, p => {
            if ( _.includes( ["d1", "d2", "observed_on", "month"], p.field ) ) {
              return false;
            }
            return p.value !== null;
          } ),
          p => [p.field, p.value]
        )
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

    // handle dates separately to avoid conflicts between the form data
    // and existing rules returned from the project details API response
    if ( this.rule_d1 ) {
      this.previewSearchParamsObject.d1 = this.rule_d1;
    }
    if ( this.rule_d2 ) {
      this.previewSearchParamsObject.d2 = this.rule_d2;
    }
    if ( !this.rule_d1 && !this.rule_d2 ) {
      if ( this.rule_observed_on ) {
        this.previewSearchParamsObject.on = this.rule_observed_on;
      } else if ( this.rule_month ) {
        this.previewSearchParamsObject.month = this.rule_month;
      }
    }
    this.previewSearchParamsString = $.param( this.previewSearchParamsObject );
  }
};

export default Project;
