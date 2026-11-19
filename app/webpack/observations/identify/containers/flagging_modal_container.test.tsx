import React from "react";
import { render, screen } from "@testing-library/react";
import { Provider } from "react-redux";
import { combineReducers, createStore } from "redux";
import flaggingModal from "../../show/ducks/flagging_modal";
import FlaggingModalContainer from "./flagging_modal_container";

jest.mock( "../actions/current_observation_actions", ( ) => ( {
  createFlag: jest.fn( ),
  deleteFlag: jest.fn( )
} ) );

describe( "FlaggingModalContainer", ( ) => {
  it( "renders the radio options the caller asked for", ( ) => {
    const store = createStore(
      combineReducers( { config: ( state = {} ) => state, flaggingModal } ),
      {
        flaggingModal: {
          show: true,
          item: { id: 1, square_url: "photo.jpg", flags: [] },
          radioOptions: ["spam", "copyright infringement", "artificially generated content"]
        }
      }
    );
    render( <Provider store={store}><FlaggingModalContainer /></Provider> );
    expect( screen.getByLabelText( /copyright/i ) ).toBeInTheDocument( );
    expect( screen.getByLabelText( /artificially/i ) ).toBeInTheDocument( );
    expect( screen.queryByLabelText( /inappropriate/i ) ).not.toBeInTheDocument( );
  } );
} );
