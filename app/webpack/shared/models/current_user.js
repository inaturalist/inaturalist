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
    return !_.isEmpty( this.id );
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
};

export default CurrentUser;
