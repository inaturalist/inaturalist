import _ from "lodash";
import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";

const StatusHeader = ( { status } ) => {
  let text = status.statusText( );
  text = I18n.t( _.snakeCase( text ), { defaultValue: text } );
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
    case "EW":
    case "EX":
      alertClass = "iucn-extinct";
      break;
    default:
      // ok
  }
  let sourceText = I18n.t( "unknown" );
  if ( status.url && status.authority ) {
    sourceText = ReactDOMServer.renderToString(
      <a href={status.url}>{ status.authority }</a>
    );
  } else if ( status.authority ) {
    sourceText = status.authority;
  } else if ( status.user ) {
    sourceText = ReactDOMServer.renderToString(
      <a href={`/people/${status.user.login}`}>{ status.user.login }</a>
    );
  }
  return (
    <div className={`alert ${alertClass} StatusHeader`}>
      <i className="glyphicon glyphicon-flag" />
      { " " }
      <strong>
        {
          status.place
            ? I18n.t( "status_in_place", { status: text, place: status.place.display_name } )
            : I18n.t( "status_globally", { status: text } )
        }
      </strong>
      <span
        dangerouslySetInnerHTML={{
          __html: ` (${I18n.t( "bold_label_colon_value_html", { label: I18n.t( "source" ), value: sourceText } )})`
        }}
      />
    </div>
  );
};

StatusHeader.propTypes = {
  status: PropTypes.object
};

export default StatusHeader;
