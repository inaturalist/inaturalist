import React from "react";
import { render } from "@testing-library/react";
import TaxonMap from "./taxon_map";

// shared/util pulls in heic-to, which jest cannot transform
jest.mock( "../../../shared/util", ( ) => ( {
  objectToComparable: object => JSON.stringify( object )
} ) );

describe( "TaxonMap", ( ) => {
  let taxonMap;
  let data;

  beforeEach( ( ) => {
    taxonMap = jest.fn( );
    data = jest.fn( );
    global.$ = jest.fn( ( ) => ( { taxonMap, data } ) );
  } );

  afterEach( ( ) => {
    delete global.google;
    delete global.$;
  } );

  describe( "when Google is blocked on an async-loading page", ( ) => {
    beforeEach( ( ) => {
      // google_maps_async_js defines this stub without any network request,
      // so google is defined but no library members are
      global.google = { maps: { importLibrary: jest.fn( ) } };
    } );

    it( "still hands the element to the taxonMap plugin, which shows its own warning", ( ) => {
      render( <TaxonMap reloadKey="a" /> );
      expect( taxonMap ).toHaveBeenCalledTimes( 1 );
    } );

    it( "does not try to resize a map that never loaded when props change", ( ) => {
      const { rerender } = render( <TaxonMap reloadKey="a" /> );
      expect( ( ) => rerender( <TaxonMap reloadKey="b" /> ) ).not.toThrow( );
      expect( taxonMap ).toHaveBeenCalledTimes( 2 );
    } );
  } );

  describe( "when the maps library has loaded", ( ) => {
    const fakeMap = { };

    beforeEach( ( ) => {
      global.google = {
        maps: {
          Map: function Map( ) { },
          event: { trigger: jest.fn( ) }
        }
      };
      data.mockReturnValue( fakeMap );
    } );

    it( "resizes the existing map when props change", ( ) => {
      const { rerender } = render( <TaxonMap reloadKey="a" /> );
      rerender( <TaxonMap reloadKey="b" /> );
      expect( global.google.maps.event.trigger ).toHaveBeenCalledWith( fakeMap, "resize" );
    } );

    it( "does not resize when props are unchanged", ( ) => {
      const { rerender } = render( <TaxonMap reloadKey="a" /> );
      rerender( <TaxonMap reloadKey="a" /> );
      expect( global.google.maps.event.trigger ).not.toHaveBeenCalled( );
    } );
  } );
} );
