import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { MAX_FILE_SIZE } from "../../observations/uploader/models/util";

const RejectedFilesError = ( { rejectedFiles } ) => {
  const errors = {};
  let showResizeTip = false;
  const namedRejectedFiles = _.filter( rejectedFiles, f => f.name && f.name.length > 0 );
  _.forEach( namedRejectedFiles, file => {
    errors[file.name] = errors[file.name] || [];
    if ( file.size > MAX_FILE_SIZE ) {
      errors[file.name].push(
        I18n.t( "uploader.errors.file_too_big", { megabytes: MAX_FILE_SIZE / 1024 / 1024 } )
      );
      showResizeTip = file.type && file.type.match( /image/ );
    }
    if ( !file.type || !file.type.match( /gif|png|jpe?g|wav|mpe?g|mp3|aac|3gpp|amr/i ) ) {
      errors[file.name].push(
        I18n.t( "uploader.errors.unsupported_file_type" )
      );
    }
    if ( window.location.search.match( /debug=true/ ) ) {
      console.log( "[DEBUG] rejected file: ", file );
    }
  } );
  if ( Object.keys( errors ).length === 0 ) {
    return null;
  }
  return (
    <div className="RejectedFilesError">
      { I18n.t( "there_were_some_problems_with_these_files" ) }
      { _.map( errors, ( fileErrors, fileName ) => (
        <div key={`file-errors-${fileName}`}>
          <code>{ fileName }</code>
          <ul>
            { _.map( fileErrors, ( error, i ) => <li key={`file-errors-${fileName}-${i}`}>{ error }</li> )}
          </ul>
        </div>
      ) )}
      <p className="small text-muted">
        { showResizeTip && I18n.t( "uploader.resize_tip" ) }
      </p>
    </div>
  );
};

RejectedFilesError.propTypes = {
  rejectedFiles: PropTypes.array
};

RejectedFilesError.defaultProps = {
  rejectedFiles: []
};

export default RejectedFilesError;
