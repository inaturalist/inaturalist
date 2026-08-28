describe( "definePhotoMarkerOverlayView", ( ) => {
  beforeEach( ( ) => {
    jest.resetModules( );
    delete global.google;
  } );

  afterEach( ( ) => {
    delete global.google;
  } );

  describe( "when google is not defined", ( ) => {
    it( "can be imported without throwing", ( ) => {
      // Regression test for WEB-1240: a top-level `extends
      // google.maps.OverlayView` threw at module evaluation time when Google
      // was blocked, taking down the whole observations-uploader bundle
      expect( ( ) => {
        // eslint-disable-next-line global-require
        require( "./photo_marker_overlay_view" );
      } ).not.toThrow( );
    } );

    it( "returns null", ( ) => {
      // eslint-disable-next-line global-require
      const definePhotoMarkerOverlayView = require( "./photo_marker_overlay_view" ).default;
      expect( definePhotoMarkerOverlayView( ) ).toBeNull( );
    } );
  } );

  describe( "when google.maps is available", ( ) => {
    class MockOverlayView { }

    beforeEach( ( ) => {
      global.google = { maps: { OverlayView: MockOverlayView } };
    } );

    it( "returns a class extending google.maps.OverlayView", ( ) => {
      // eslint-disable-next-line global-require
      const definePhotoMarkerOverlayView = require( "./photo_marker_overlay_view" ).default;
      const PhotoMarkerOverlayView = definePhotoMarkerOverlayView( );
      const latLng = { lat: 1, lng: 2 };
      const overlay = new PhotoMarkerOverlayView( "http://example.com/photo.jpg", latLng );
      expect( overlay ).toBeInstanceOf( MockOverlayView );
      expect( overlay.imgUrl ).toBe( "http://example.com/photo.jpg" );
      expect( overlay.latLng ).toBe( latLng );
    } );

    it( "memoizes the class between calls", ( ) => {
      // eslint-disable-next-line global-require
      const definePhotoMarkerOverlayView = require( "./photo_marker_overlay_view" ).default;
      expect( definePhotoMarkerOverlayView( ) ).toBe( definePhotoMarkerOverlayView( ) );
    } );

    it( "defines the class even if a previous call ran without google", ( ) => {
      // eslint-disable-next-line global-require
      const definePhotoMarkerOverlayView = require( "./photo_marker_overlay_view" ).default;
      delete global.google;
      expect( definePhotoMarkerOverlayView( ) ).toBeNull( );
      global.google = { maps: { OverlayView: MockOverlayView } };
      expect( definePhotoMarkerOverlayView( ) ).not.toBeNull( );
    } );
  } );
} );
