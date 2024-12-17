import _ from "lodash";

const Config = class Config {
  constructor( attrs = { } ) {
    Object.assign( this, attrs );
  }

  currentUserCanInteractWithResource( resource ) {
    if ( _.isEmpty( this.currentUser ) ) {
      return false;
    }
    if ( this.currentUser.id === resource?.user?.id
      || this?.currentUser?.privilegedWith( "interaction" )
    ) {
      return true;
    }
    return false;
  }
};

export default Config;
