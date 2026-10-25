import { cardTimeItems, cardTimeMs, countItemsDuringActivity } from "./track_matching";

jest.mock( "./util", ( ) => ( {
  parsableDatetimeFormat: ( ) => "YYYY/MM/DD h:mm A"
} ) );

const t = iso => Date.parse( iso );
const timeZone = "America/Los_Angeles";

describe( "cardTimeMs", ( ) => {
  it( "uses the EXIF offset regardless of the fallback zone", ( ) => {
    const card = { id: 1, date: "2024/06/01 10:00 AM" };
    const files = {
      10: {
        cardID: 1,
        metadata: {
          date: "2024/06/01 10:00 AM",
          exifDateTime: "2024-06-01 10:00:30",
          exifOffset: "+09:00"
        }
      }
    };
    expect( cardTimeMs( card, files, { timeZone } ) ).toBe( t( "2024-06-01T01:00:30Z" ) );
  } );

  it( "uses the fallback zone for EXIF without an offset", ( ) => {
    const card = { id: 1 };
    const files = {
      10: { cardID: 1, metadata: { date: "2024/06/01 10:00 AM", exifDateTime: "2024-06-01 10:00:30" } }
    };
    expect( cardTimeMs( card, files, { timeZone } ) ).toBe( t( "2024-06-01T17:00:30Z" ) );
  } );

  it( "prefers a date the user changed over EXIF", ( ) => {
    const card = { id: 1, date: "2024/06/01 11:00 AM" };
    const files = {
      10: {
        cardID: 1,
        metadata: { date: "2024/06/01 10:00 AM", exifDateTime: "2024-06-01 10:00:30", exifOffset: "-07:00" }
      }
    };
    expect( cardTimeMs( card, files, { timeZone } ) ).toBe( t( "2024-06-01T18:00:00Z" ) );
  } );

  it( "applies the clock offset", ( ) => {
    const card = { id: 1, date: "2024/06/01 10:00 AM" };
    expect( cardTimeMs( card, {}, { timeZone, clockOffsetMs: 60000 } ) ).toBe( t( "2024-06-01T17:01:00Z" ) );
  } );

  it( "returns null without a date", ( ) => {
    expect( cardTimeMs( { id: 1 }, {}, { timeZone } ) ).toBeNull( );
  } );
} );

describe( "cardTimeItems", ( ) => {
  it( "returns items for cards with a resolvable time", ( ) => {
    const obsCards = { 1: { id: 1, date: "2024/06/01 10:00 AM" }, 2: { id: 2 } };
    expect( cardTimeItems( obsCards, {}, { timeZone } ) ).toEqual( [
      { id: 1, timeMs: t( "2024-06-01T17:00:00Z" ) }
    ] );
  } );
} );

describe( "countItemsDuringActivity", ( ) => {
  const activity = { startTimeMs: t( "2024-06-01T17:00:00Z" ), durationMs: 60 * 60 * 1000 };
  const items = [
    { id: 1, timeMs: t( "2024-06-01T16:40:00Z" ) },
    { id: 2, timeMs: t( "2024-06-01T17:30:00Z" ) },
    { id: 3, timeMs: t( "2024-06-01T18:20:00Z" ) },
    { id: 4, timeMs: t( "2024-06-01T19:00:00Z" ) }
  ];

  it( "counts items within the activity and the extrapolation window", ( ) => {
    expect( countItemsDuringActivity( items, activity ) ).toBe( 3 );
    expect( countItemsDuringActivity( items, activity, 0 ) ).toBe( 1 );
  } );

  it( "counts nothing for an activity without a start time", ( ) => {
    expect( countItemsDuringActivity( items, { startTimeMs: NaN } ) ).toBe( 0 );
  } );
} );
