import React from "react";
import PropTypes from "prop-types";

const UserError = ( { user, attribute, alias } ) => {
  const hasErrors = user.errors && user.errors[attribute];
  if ( !hasErrors ) return null;
  let errorTranslationKey = alias || attribute;
  if ( errorTranslationKey === "description" ) {
    errorTranslationKey = "bio";
  }
  // I18n.t( "activerecord.attributes.user.faved_project_ids" )
  const translatedAttribute = I18n.t( errorTranslationKey, {
    defaultValue: I18n.t( `activerecord.attributes.user.${attribute}` )
  } );
  return (
    <div>
      {user.errors[attribute].map( reason => (
        <div className="error-message" key={reason}>
          {`${translatedAttribute} ${reason}`}
        </div>
      ) )}
    </div>
  );
};

UserError.propTypes = {
  user: PropTypes.object,
  alias: PropTypes.string,
  attribute: PropTypes.string
};

export default UserError;
