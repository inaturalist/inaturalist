import React from "react";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import PhotoDescription from "./photo_description";

jest.mock( "../containers/hidden_content_message_container", ( ) => ( {
  __esModule: true,
  default: ( ) => <div data-testid="hidden-message" />
} ) );

const observer = { id: 1, roles: [] as string[] };
const curator = { id: 2, roles: ["curator"] };
const admin = { id: 3, roles: ["admin"] };
const observation = { id: 10, user: { id: observer.id, login: "obs" } };
const photo = { id: 100, license_code: "cc-by" };
const hiddenBy = ( user: { id: number }, extra = { } ) => ( {
  ...photo,
  hidden: true,
  moderator_actions: [{
    id: 7, action: "hide", created_at: "2026-01-01", user, ...extra
  }]
} );

const renderDescription = (
  props: Partial<React.ComponentProps<typeof PhotoDescription>> = { }
) => {
  const callbacks = {
    setFlaggingModalState: jest.fn( ),
    hideContent: jest.fn( ),
    unhideContent: jest.fn( ),
    revealHiddenContent: jest.fn( ),
    performOrOpenConfirmationModal: jest.fn( ( method: ( ) => void ) => method( ) )
  };
  render(
    <PhotoDescription
      photo={photo}
      observation={observation}
      currentUser={curator}
      {...callbacks}
      {...props}
    />
  );
  return callbacks;
};

describe( "PhotoDescription", ( ) => {
  it( "links to the photo page", ( ) => {
    renderDescription( );
    expect( screen.getByRole( "link" ) ).toHaveAttribute( "href", "/photos/100" );
  } );

  it( "opens the flagging modal through the confirmation gate", async ( ) => {
    const { performOrOpenConfirmationModal, setFlaggingModalState } = renderDescription( );
    await userEvent.click( screen.getByTitle( "flag_as_inappropriate" ) );
    expect( performOrOpenConfirmationModal ).toHaveBeenCalledWith(
      expect.any( Function ),
      { permitOwnerOf: observation }
    );
    expect( setFlaggingModalState ).toHaveBeenCalledWith( expect.objectContaining( {
      item: photo,
      show: true
    } ) );
  } );

  it( "never offers the observer a hide button", ( ) => {
    renderDescription( { currentUser: observer } );
    expect( screen.queryByTitle( "hide_content" ) ).not.toBeInTheDocument( );
  } );

  it( "lets a curator hide a visible photo", async ( ) => {
    const { hideContent } = renderDescription( );
    await userEvent.click( screen.getByTitle( "hide_content" ) );
    expect( hideContent ).toHaveBeenCalledWith( photo );
  } );

  it( "lets the hiding curator unhide and reveal the photo", async ( ) => {
    const hidden = hiddenBy( curator );
    const { unhideContent, revealHiddenContent } = renderDescription( { photo: hidden } );
    expect( screen.getByTestId( "hidden-message" ) ).toBeInTheDocument( );
    await userEvent.click( screen.getByTitle( "unhide_content" ) );
    expect( unhideContent ).toHaveBeenCalledWith( hidden );
    await userEvent.click( screen.getByText( "show_hidden_content" ) );
    expect( revealHiddenContent ).toHaveBeenCalledWith( hidden );
  } );

  it( "hides unhide from curators who did not hide the photo", ( ) => {
    renderDescription( { photo: hiddenBy( admin ) } );
    expect( screen.queryByTitle( "unhide_content" ) ).not.toBeInTheDocument( );
  } );

  it( "only lets admins reveal privately hidden photos", ( ) => {
    renderDescription( { photo: hiddenBy( curator, { private: true } ) } );
    expect( screen.queryByText( "show_hidden_content" ) ).not.toBeInTheDocument( );
  } );

  it( "lets admins re-hide a hidden photo to make it private", async ( ) => {
    const hidden = hiddenBy( curator );
    const { hideContent } = renderDescription( { photo: hidden, currentUser: admin } );
    await userEvent.click( screen.getAllByTitle( "hide_content" )[0] );
    expect( hideContent ).toHaveBeenCalledWith( hidden );
  } );
} );
