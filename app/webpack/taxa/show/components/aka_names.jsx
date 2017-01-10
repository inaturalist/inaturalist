import React, { PropTypes } from "react";

const AkakNames = ( { names } ) => (
  <div className="AkaNames text-muted">
    { names.length > 0 ? `${I18n.t( "aka" ).toUpperCase( )} ` : "" }
    <span className="comma-separated-list">
      { names.map( taxonName => (
        <span key={`aka-names-${taxonName.id}`}>
          <span className="name">{ taxonName.name }</span> ({taxonName.lexicon})
        </span>
      ) ) }
    </span>
  </div>
);

AkakNames.propTypes = {
  names: PropTypes.array
};

AkakNames.defaultProps = {
  names: []
};

export default AkakNames;
