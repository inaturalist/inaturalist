import React, { useCallback, useState } from "react";
import { useDropzone } from "react-dropzone-modern";
import inatjs from "inaturalistjs";
import { MAX_FILE_SIZE } from "../../observations/uploader/models/util";

// react-dropzone-modern is react-dropzone@14 installed under an alias so the new
// hooks API can be used here without disturbing the 8 call sites still on the
// pinned v4 render-prop API. Remove the alias once those are migrated.

// v14 `accept` is an object of mimetype -> extensions, unlike the v4 MIME string.
// Photos only (comments don't take sounds/video), matching Photo::MIME_PATTERNS.
const ACCEPT = {
  "image/jpeg": [],
  "image/png": [],
  "image/gif": [],
  "image/heic": [],
  "image/heif": []
};

// Records ownership of a freshly uploaded comment photo (same-origin, so it
// never touches the node API). Rejects on a non-2xx (e.g. the upload throttle)
// so the caller can keep the markdown out of the comment body.
const createCommentPhoto = ( photoId: number ): Promise<void> => {
  const csrf = document.querySelector<HTMLMetaElement>( "meta[name=csrf-token]" )?.content;
  return fetch( "/comment_photos", {
    method: "POST",
    credentials: "same-origin",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...( csrf ? { "X-CSRF-Token": csrf } : {} )
    },
    body: JSON.stringify( { photo_id: photoId } )
  } ).then( response => {
    if ( !response.ok ) { throw new Error( "comment photo not created" ); }
  } );
};

interface Props {
  // Called with the markdown for each uploaded photo, ready to append to the body.
  onInsert: ( markdown: string ) => void;
  // The editor textarea, wrapped so a file can be dropped directly onto the field.
  children?: React.ReactNode;
  // Receives the file-dialog opener so a trigger can live elsewhere (e.g. the
  // editor toolbar) rather than as a separate section under the field.
  openRef?: React.MutableRefObject<( ( ) => void ) | null>;
}

const CommentPhotoDropzone = ( { onInsert, children, openRef }: Props ): React.ReactElement => {
  const [uploading, setUploading] = useState( false );
  const [error, setError] = useState<string | null>( null );

  const onDrop = useCallback( ( acceptedFiles: File[] ) => {
    if ( acceptedFiles.length === 0 ) { return; }
    setError( null );
    setUploading( true );
    Promise.all( acceptedFiles.map( file => (
      inatjs.photos.create( { file }, { same_origin: true } )
        .then( ( photo: { id: number; medium_url: string } ) => (
          // Embed only after the join is recorded.
          createCommentPhoto( photo.id ).then( ( ) => {
            onInsert( `\n![](${photo.medium_url})\n` );
          } )
        ) )
    ) ) )
      .catch( ( ) => { setError( I18n.t( "failed_to_save_record" ) ); } )
      .then( ( ) => { setUploading( false ); } );
  }, [onInsert] );

  const {
    getRootProps, getInputProps, open, isDragActive
  } = useDropzone( {
    onDrop,
    accept: ACCEPT,
    maxSize: MAX_FILE_SIZE,
    noClick: true,
    noKeyboard: true
  } );

  // Expose the opener to the parent (assigned during render so it's set before
  // any toolbar trigger is clicked).
  if ( openRef ) { openRef.current = open; }

  return (
    // react-dropzone requires spreading its prop getters onto the elements.
    /* eslint-disable react/jsx-props-no-spreading */
    <div {...getRootProps( {
      className: `CommentPhotoDropzone${isDragActive ? " drag-active" : ""}`,
      style: {
        position: "relative",
        ...( isDragActive ? { outline: "2px dashed #74ac00", outlineOffset: "-2px" } : {} )
      }
    } )}
    >
      <input {...getInputProps( )} />
      { children }
      { uploading && (
        <div
          className="text-muted"
          style={{ position: "absolute", top: 6, right: 10 }}
        >
          <i className="fa fa-spinner fa-spin" />
        </div>
      ) }
      { error && <div className="text-danger small">{ error }</div> }
    </div>
    /* eslint-enable react/jsx-props-no-spreading */
  );
};

export default CommentPhotoDropzone;
