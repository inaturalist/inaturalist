import _ from "lodash";

const CurrentUser = class CurrentUser {
  constructor( attrs = { } ) {
    Object.assign( this, _.omit(
      attrs,
      ["loggedIn", "isAdmin", "isCurator"]
    ) );
    this.loggedIn = this.loggedIn( );
    this.isAdmin = this.isAdmin( );
    this.isCurator = this.isCurator( );
  }

  loggedIn( ) {
    return _.isNumber( this.id );
  }

  isAdmin( ) {
    if ( !_.isArray( this.roles ) ) {
      return false;
    }
    return this.roles.includes( "admin" );
  }

  isCurator( ) {
    if ( !_.isArray( this.roles ) ) {
      return false;
    }
    return this.roles.includes( "admin" )
      || this.roles.includes( "curator" );
  }

  privilegedWith( privilege ) {
    if ( !_.isArray( this.privileges ) ) {
      return false;
    }
    return this.privileges.includes( privilege );
  }

  canNominateIdentification( identification ) {
    if (
      !identification.current
      || identification.hidden
      || !this.loggedIn
      || _.isEmpty( _.trim( identification.body ) )
      || !this.canNominateHelpfulIDTips( )
    ) {
      return false;
    }
    return true;
  }

  canUnnominateIdentification( identification ) {
    if ( this.loggedIn
      && (
        this.canNominateHelpfulIDTips( )
        || identification.user.id === this.id
      )
    ) {
      return true;
    }
    return false;
  }

  canNominateHelpfulIDTips( ) {
    return this.loggedIn && !this.content_creation_restrictions;
  }

  isInTestGroup( testGroup ) {
    return this.testGroups && this.testGroups.indexOf( testGroup ) >= 0;
  }

  // The config duck attaches loadFeatureFlags; the first read fetches the map and merges it back
  // onto this instance, and every read waits for that one request. A missing map or key is off,
  // as in Rails.
  async featureFlagEnabled( flag ) {
    if ( _.isUndefined( this.featureFlags ) && _.isFunction( this.loadFeatureFlags ) ) {
      this.featureFlagsRequest = this.featureFlagsRequest || this.loadFeatureFlags( );
      try {
        await this.featureFlagsRequest;
      } catch ( e ) {
        // Fail closed: a failed load leaves every flag off.
      }
    }
    return !!( _.isPlainObject( this.featureFlags ) && this.featureFlags[flag] );
  }
};

export default CurrentUser;
