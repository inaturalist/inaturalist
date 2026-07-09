// util.js imports COLORS from shared/util, which transitively pulls in
// browser-only deps (heic-to, etc.) that Jest can't transform. COLORS is only
// used by functions we don't exercise here, so stub the module.
import {
  urlForTaxon,
  urlForTaxonPhotos,
  getChosenTab,
  RANK_LEVELS
} from "./util";

jest.mock( "../../shared/util", ( ) => ( { COLORS: { } } ) );

describe( "urlForTaxon", ( ) => {
  it( "builds a slugified taxon path", ( ) => {
    expect( urlForTaxon( { id: 5, name: "Panthera leo" } ) ).toBe( "/taxa/5-Panthera-leo" );
  } );

  it( "replaces non-alphanumeric characters with hyphens", ( ) => {
    expect( urlForTaxon( { id: 7, name: "Abies × shastensis" } ) ).toBe( "/taxa/7-Abies---shastensis" );
  } );

  it( "returns null for a falsy taxon", ( ) => {
    expect( urlForTaxon( null ) ).toBeNull( );
  } );
} );

describe( "urlForTaxonPhotos", ( ) => {
  it( "builds the browse_photos path", ( ) => {
    expect( urlForTaxonPhotos( { id: 1, name: "Test" } ) ).toBe( "/taxa/1-Test/browse_photos" );
  } );

  it( "appends query params when provided", ( ) => {
    expect( urlForTaxonPhotos( { id: 1, name: "Test" }, { place_id: 2, user_id: 3 } ) )
      .toBe( "/taxa/1-Test/browse_photos?place_id=2&user_id=3" );
  } );
} );

describe( "getChosenTab", ( ) => {
  it( "rejects a genus-only tab at species rank", ( ) => {
    expect( getChosenTab( "highlights", RANK_LEVELS.species ) ).toBeNull( );
  } );

  it( "allows a genus tab at genus rank", ( ) => {
    expect( getChosenTab( "highlights", RANK_LEVELS.genus ) ).toBe( "highlights" );
  } );

  it( "allows a species-only tab at species rank", ( ) => {
    expect( getChosenTab( "interactions", RANK_LEVELS.species ) ).toBe( "interactions" );
  } );

  it( "allows map above genus but not species-only tabs", ( ) => {
    expect( getChosenTab( "map", RANK_LEVELS.family ) ).toBe( "map" );
    expect( getChosenTab( "interactions", RANK_LEVELS.family ) ).toBeNull( );
  } );

  it( "returns null for an unknown tab", ( ) => {
    expect( getChosenTab( "curation", RANK_LEVELS.species ) ).toBeNull( );
  } );
} );
