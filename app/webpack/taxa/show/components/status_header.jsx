import React, { PropTypes } from "react";
import _ from "lodash";

const StatusHeader = ( { status } ) => {
  let text = status.statusText( );
  text = I18n.t( text, { defaultValue: text } );
  text = _.capitalize( text );
  // if ( !text.match( /\(${status.status}\)/ ) ) {
  //   text += ` (${status.status})`;
  // }
  let alertClass;
  switch ( status.iucnStatusCode( ) ) {
    case "LC":
      alertClass = "iucn-least-concern";
      break;
    case "NT":
    case "VU":
      alertClass = "iucn-vulnerable";
      break;
    case "CR":
    case "EN":
      alertClass = "iucn-endangered";
      break;
    default:
      // ok
  }
  return (
    <div className={`alert ${alertClass} StatusHeader`}>
      <i className="glyphicon glyphicon-flag">
      </i> <strong>{
        status.place ?
          I18n.t( "status_in_place", { status: text, place: status.place.display_name } )
          :
          I18n.t( "status_globally", { status: text } )
      }</strong> (
        { I18n.t( "source" ) }: <a href={status.url}>{ status.authority }</a>
      )
    </div>
  );
};

StatusHeader.propTypes = {
  status: PropTypes.object
};

export default StatusHeader;
