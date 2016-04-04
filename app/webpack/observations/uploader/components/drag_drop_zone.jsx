import React, { PropTypes } from "react";
import Dropzone from "react-dropzone";
import Card from "./card";

const DragDropZone = ( { onDrop, nameChange, descriptionChange, files = [] } ) => (
  <Dropzone onDrop={ onDrop } className="uploader" disableClick disablePreview>
    <div>
      { _.map( files, ( file, k ) => (
          <Card key={file.id}
            file={file}
            nameChange={ e => nameChange( file, e ) }
            descriptionChange={ e => descriptionChange( file, e ) }
          />
      ) ) }
    </div>

    <div>Try dropping some files here to upload.</div>
  </Dropzone>
);

DragDropZone.propTypes = {
  onDrop: PropTypes.func.isRequired,
  nameChange: PropTypes.func,
  descriptionChange: PropTypes.func,
  files: PropTypes.object,
  actions: PropTypes.object
};

export default DragDropZone;
