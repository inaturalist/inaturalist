import React from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import TrackStatusBar from "./track_status_bar";

const gpsTrack = {
  fileName: "walk.gpx",
  points: [{ lat: 1, lng: 1, timeMs: 0 }],
  timeZone: "America/Los_Angeles",
  clockOffsetMs: 0,
  matchedLocations: { 1: {}, 2: {} }
};

function renderBar( props = {} ) {
  const handlers = {
    removeGpsTrack: jest.fn( ),
    applyTrackLocations: jest.fn( ),
    setTrackClockOffset: jest.fn( )
  };
  render( <TrackStatusBar gpsTrack={gpsTrack} {...handlers} {...props} /> );
  return handlers;
}

describe( "TrackStatusBar", ( ) => {
  it( "renders nothing without a track", ( ) => {
    const { container } = render( <TrackStatusBar gpsTrack={null} /> );
    expect( container ).toBeEmptyDOMElement( );
  } );

  it( "shows the file name", ( ) => {
    renderBar( );
    expect( screen.getByText( "walk.gpx" ) ).toBeInTheDocument( );
  } );

  it( "commits the clock offset in ms on Enter, not on every keystroke", ( ) => {
    const { setTrackClockOffset } = renderBar( );
    const input = screen.getByRole( "spinbutton" );
    fireEvent.change( input, { target: { value: "-5" } } );
    expect( setTrackClockOffset ).not.toHaveBeenCalled( );
    fireEvent.keyDown( input, { key: "Enter" } );
    expect( setTrackClockOffset ).toHaveBeenCalledWith( -5 * 60 * 1000 );
  } );

  it( "doesn't re-match on blur when the offset is unchanged", ( ) => {
    const { setTrackClockOffset } = renderBar( );
    fireEvent.blur( screen.getByRole( "spinbutton" ) );
    expect( setTrackClockOffset ).not.toHaveBeenCalled( );
  } );

  it( "applies to all with overrideExisting and removes the track", ( ) => {
    const { applyTrackLocations, removeGpsTrack } = renderBar( );
    fireEvent.click( screen.getByText( "gps_track_apply_to_all" ) );
    expect( applyTrackLocations ).toHaveBeenCalledWith( { overrideExisting: true } );
    fireEvent.click( screen.getByText( "gps_track_remove" ) );
    expect( removeGpsTrack ).toHaveBeenCalled( );
  } );
} );
