import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { MAX_FILE_SIZE } from "../../observations/uploader/models/util";

const RejectedFilesError = ( {
  rejectedFiles,
  supportedFilesRegex,
  unsupportedFileTypeMessage,
  maxFileSizeInBytes
} ) => {
  const errors = {};
  let showResizeTip = false;
  const namedRejectedFiles = _.filter( rejectedFiles, f => f.name && f.name.length > 0 );
  _.forEach( namedRejectedFiles, file => {
    errors[file.name] = errors[file.name] || [];
    if ( file.size > maxFileSizeInBytes ) {
      errors[file.name].push(
        I18n.t( "uploader.errors.file_too_big", { megabytes: maxFileSizeInBytes / 1024 / 1024 } )
      );
      showResizeTip = file.type && file.type.match( /image/ );
    }
    if ( !file.type || !file.type.match( new RegExp( supportedFilesRegex, "i" ) ) ) {
      errors[file.name].push(
        unsupportedFileTypeMessage
      );
    }
    if ( window.location.search.match( /debug=true/ ) ) {
      console.log( "[DEBUG] rejected file: ", file );
    }
  } );
  if ( _.keys( errors ).length === 0 ) {
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
  rejectedFiles: PropTypes.array,
  supportedFilesRegex: PropTypes.string,
  unsupportedFileTypeMessage: PropTypes.string,
  maxFileSizeInBytes: PropTypes.number
};

RejectedFilesError.defaultProps = {
  rejectedFiles: [],
  supportedFilesRegex: "gif|png|jpe?g|wav|mpe?g|mp3|aac|3gpp|amr|mp4",
  unsupportedFileTypeMessage: I18n.t( "uploader.errors.unsupported_file_type" ),
  maxFileSizeInBytes: MAX_FILE_SIZE
};

export default RejectedFilesError;
