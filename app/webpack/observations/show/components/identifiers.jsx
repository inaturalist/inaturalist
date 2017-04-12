import _ from "lodash";
import React, { PropTypes } from "react";
import UserImage from "../../identify/components/user_image";

const Identifiers = ( { observation, identifiers } ) => {
  if ( _.isEmpty( identifiers ) ) { return ( <span /> ); }
  const taxon = observation.taxon;
  return (
    <div className="Identifiers">
      <h4>
        { I18n.t( "top_identifiers_of_taxon", {
          taxon: taxon.preferred_common_name || taxon.name } ) }
      </h4>
      { identifiers.map( i => (
        <div className="identifier" key={ `identifier-${i.user.id}` }>
          <div className="UserWithIcon">
            <div className="icon">
              <UserImage user={ i.user } />
            </div>
            <div className="title">
              <a href={ `/people/${i.user.login}` }>{ i.user.login }</a>
            </div>
            <div className="subtitle">
              <i className="icon-identification" />
              { i.count }
            </div>
          </div>
        </div>
      ) ) }
    </div>
  );
};

Identifiers.propTypes = {
  observation: PropTypes.object,
  identifiers: PropTypes.array
};

export default Identifiers;
