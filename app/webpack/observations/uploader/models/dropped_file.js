const DroppedFile = class DroppedFile {
  constructor( attrs ) {
    Object.assign( this, attrs );
  }

  static fromFile( file, id ) {
    return new DroppedFile( {
      id,
      name: file.name,
      lastModified: file.lastModified,
      lastModifiedDate: file.lastModifiedDate,
      size: file.size,
      type: file.type,
      upload_state: "pending",
      file
    } );
  }
};

export default DroppedFile;
