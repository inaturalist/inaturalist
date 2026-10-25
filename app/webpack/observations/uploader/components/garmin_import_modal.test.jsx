import React from "react";
import { fireEvent, render, screen } from "@testing-library/react";
import GarminImportModal from "./garmin_import_modal";

jest.mock( "../models/util", ( ) => ( {
  parsableDatetimeFormat: ( ) => "YYYY/MM/DD h:mm A"
} ) );

const garminState = {
  enabled: true,
  show: true,
  token: null,
  activities: null,
  hasMore: false,
  loading: false,
  importingId: null,
  error: null
};

const walk = {
  id: 1,
  name: "Morning Walk",
  type: "walking",
  startTimeMs: Date.parse( "2024-06-01T17:00:00Z" ),
  durationMs: 90 * 60 * 1000,
  distanceM: 5200,
  hasTrack: true
};
const treadmill = {
  ...walk,
  id: 2,
  name: "Treadmill",
  hasTrack: false
};

function renderModal( garmin = {}, props = {} ) {
  const handlers = {
    closeGarminImport: jest.fn( ),
    connectGarmin: jest.fn( ),
    disconnectGarmin: jest.fn( ),
    importGarminActivity: jest.fn( ),
    loadGarminActivities: jest.fn( )
  };
  render( <GarminImportModal garmin={{ ...garminState, ...garmin }} {...handlers} {...props} /> );
  return handlers;
}

describe( "GarminImportModal", ( ) => {
  it( "renders nothing when the flag is off", ( ) => {
    renderModal( { enabled: false } );
    expect( screen.queryByText( "gps_track_garmin_title" ) ).not.toBeInTheDocument( );
  } );

  it( "asks for a key, connects with it, and clears the field", ( ) => {
    const { connectGarmin } = renderModal( );
    const input = screen.getByLabelText( "gps_track_garmin_api_key" );
    expect( input ).toHaveAttribute( "type", "password" );
    expect( screen.getByText( "gps_track_garmin_get_key" ).closest( "a" ) )
      .toHaveAttribute( "href", "https://connect.garmin.com/app/settings/personalApiToken" );
    fireEvent.change( input, { target: { value: " key-123 " } } );
    fireEvent.click( screen.getByText( "gps_track_garmin_connect" ) );
    expect( connectGarmin ).toHaveBeenCalledWith( " key-123 " );
    expect( input ).toHaveValue( "" );
  } );

  it( "doesn't connect with a blank key", ( ) => {
    const { connectGarmin } = renderModal( );
    fireEvent.change( screen.getByLabelText( "gps_track_garmin_api_key" ), { target: { value: "  " } } );
    fireEvent.submit( screen.getByLabelText( "gps_track_garmin_api_key" ).closest( "form" ) );
    expect( connectGarmin ).not.toHaveBeenCalled( );
  } );

  it( "shows errors", ( ) => {
    renderModal( { error: "Garmin said no" } );
    expect( screen.getByText( "Garmin said no" ) ).toBeInTheDocument( );
  } );

  it( "lists activities with photo counts and imports one", ( ) => {
    const obsCards = { 10: { id: 10 } };
    const files = {
      20: {
        cardID: 10,
        metadata: { date: "x", exifDateTime: "2024-06-01 17:30:00", exifOffset: "+00:00" }
      }
    };
    const { importGarminActivity } = renderModal(
      { token: { accessToken: "t" }, activities: [walk, treadmill] },
      { obsCards, files }
    );
    expect( screen.getByText( "Morning Walk" ) ).toBeInTheDocument( );
    expect( screen.getAllByText( /1:30 · gps_track_garmin_distance_km/ ) ).toHaveLength( 2 );
    expect( screen.getAllByText( "x_photos" ) ).toHaveLength( 2 );
    expect( screen.getByText( "gps_track_garmin_no_gps" ) ).toBeInTheDocument( );
    const importButtons = screen.getAllByText( "import" );
    expect( importButtons ).toHaveLength( 1 );
    fireEvent.click( importButtons[0] );
    expect( importGarminActivity ).toHaveBeenCalledWith( walk );
  } );

  it( "disables importing while another import runs", ( ) => {
    renderModal( { token: { accessToken: "t" }, activities: [walk, { ...walk, id: 3 }], importingId: 1 } );
    expect( screen.getByText( "import" ).closest( "button" ) ).toBeDisabled( );
  } );

  it( "loads more and disconnects", ( ) => {
    const { loadGarminActivities, disconnectGarmin } = renderModal( {
      token: { accessToken: "t" },
      activities: [walk],
      hasMore: true
    } );
    fireEvent.click( screen.getByText( "show_more" ) );
    expect( loadGarminActivities ).toHaveBeenCalledWith( { more: true } );
    fireEvent.click( screen.getByText( "disconnect" ) );
    expect( disconnectGarmin ).toHaveBeenCalled( );
  } );
} );
