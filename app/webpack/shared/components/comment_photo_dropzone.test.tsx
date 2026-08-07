import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import inatjs from "inaturalistjs";
import CommentPhotoDropzone from "./comment_photo_dropzone";

jest.mock( "inaturalistjs", ( ) => ( {
  __esModule: true,
  default: { photos: { create: jest.fn( ) } }
} ) );

const photosCreate = ( inatjs as unknown as {
  photos: { create: jest.Mock };
} ).photos.create;

const jpeg = ( ) => new File( ["x"], "beetle.jpg", { type: "image/jpeg" } );

const fileInput = ( container: HTMLElement ) => (
  container.querySelector( "input[type=\"file\"]" ) as HTMLInputElement
);

describe( "CommentPhotoDropzone", ( ) => {
  it( "wraps its children (the text field) as the drop target", ( ) => {
    render(
      <CommentPhotoDropzone onInsert={jest.fn( )}>
        <textarea aria-label="body" />
      </CommentPhotoDropzone>
    );
    // the field itself is inside the dropzone; there is no separate button here
    expect( screen.getByLabelText( "body" ) ).toBeInTheDocument( );
    expect( screen.queryByRole( "button" ) ).not.toBeInTheDocument( );
  } );

  it( "hands its file-dialog opener to openRef", ( ) => {
    const openRef: React.MutableRefObject< ( ( ) => void ) | null > = { current: null };
    render(
      <CommentPhotoDropzone onInsert={jest.fn( )} openRef={openRef}>
        <textarea />
      </CommentPhotoDropzone>
    );
    expect( typeof openRef.current ).toBe( "function" );
  } );

  it( "uploads a dropped file and inserts markdown pointing at its medium_url", async ( ) => {
    photosCreate.mockResolvedValue( {
      medium_url: "https://static.inaturalist.org/photos/42/medium.jpg"
    } );
    const onInsert = jest.fn( );
    const { container } = render(
      <CommentPhotoDropzone onInsert={onInsert}><textarea /></CommentPhotoDropzone>
    );
    await userEvent.upload( fileInput( container ), jpeg( ) );

    await waitFor( ( ) => expect( photosCreate ).toHaveBeenCalledTimes( 1 ) );
    expect( photosCreate.mock.calls[0][0] ).toEqual( { file: expect.any( File ) } );
    expect( photosCreate.mock.calls[0][1] ).toEqual( { same_origin: true } );
    await waitFor( ( ) => expect( onInsert ).toHaveBeenCalledWith(
      "\n![](https://static.inaturalist.org/photos/42/medium.jpg)\n"
    ) );
    // spinner clears once the upload settles (also flushes state inside act)
    await waitFor( ( ) => expect( container.querySelector( ".fa-spinner" ) ).toBeNull( ) );
  } );

  it( "does not insert when the upload fails", async ( ) => {
    photosCreate.mockRejectedValue( new Error( "boom" ) );
    const onInsert = jest.fn( );
    const { container } = render(
      <CommentPhotoDropzone onInsert={onInsert}><textarea /></CommentPhotoDropzone>
    );
    await userEvent.upload( fileInput( container ), jpeg( ) );

    await waitFor( ( ) => expect( photosCreate ).toHaveBeenCalledTimes( 1 ) );
    await waitFor( ( ) => expect( container.querySelector( ".fa-spinner" ) ).toBeNull( ) );
    expect( onInsert ).not.toHaveBeenCalled( );
  } );
} );
