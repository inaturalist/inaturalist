import React from "react";
import PropTypes from "prop-types";

const EstablishmentHeader = ( { establishmentMeans, source, url } ) => {
  let sourceElement;
  if ( !establishmentMeans ) {
    return <div className="alert establishment-endemic StatusHeader EstablishmentHeader" />;
  }
  if ( url ) {
    sourceElement = (
      <span>
        { "(" }
        { I18n.t( "label_colon", { label: I18n.t( "source_list_" ) } ) }
        { " " }
        <a href={url}>{ source || url }</a>
        { ")" }
      </span>
    );
  }
  if ( establishmentMeans.establishment_means === "endemic" ) {
    return (
      <div className="alert establishment-endemic StatusHeader EstablishmentHeader">
        <i className="glyphicon glyphicon-star" />
        { " " }
        <strong>
          { I18n.t( "endemic_to_x", { x: establishmentMeans.place.display_name } ) }
        </strong>
        { " " }
        { sourceElement }
      </div>
    );
  }
  if ( establishmentMeans.establishment_means === "native" ) {
    return (
      <div className="alert establishment-endemic StatusHeader EstablishmentHeader">
        <strong>
          { I18n.t( "native_to_place", { place: establishmentMeans.place.display_name } ) }
        </strong>
        { " " }
        { sourceElement }
      </div>
    );
  }
  if ( establishmentMeans.establishment_means === "introduced" ) {
    return (
      <div className="alert establishment-introduced StatusHeader EstablishmentHeader">
        <i className="glyphicon glyphicon-alert" />
        { " " }
        <strong>
          { I18n.t( "introduced_in_place", { place: establishmentMeans.place.display_name } ) }
        </strong>
        { " " }
        { sourceElement }
      </div>
    );
  }
  return <div />;
};

EstablishmentHeader.propTypes = {
  establishmentMeans: PropTypes.object,
  source: PropTypes.string,
  url: PropTypes.string
};

export default EstablishmentHeader;
