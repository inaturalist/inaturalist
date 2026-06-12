import { addAdditionalObserver, removeAdditionalObserver } from "./additional_observers";

// Avoid pulling in the heavy observation duck (inatjs + browser-only deps).
// We only need its two action creators, stubbed to plain action objects.
jest.mock( "./observation", ( ) => ( {
  setAttributes: jest.fn( attributes => ( { type: "SET_ATTRIBUTES", attributes } ) ),
  fetchObservation: jest.fn( uuid => ( { type: "FETCH_OBSERVATION", uuid } ) )
} ) );

describe( "additional_observers duck", ( ) => {
  const observer = { id: 99, login: "newbie" };
  let dispatched;

  const stateWith = additionalObservers => ( {
    config: { currentUser: { id: 1 } },
    observation: { id: 42, uuid: "abc-123", additional_observers: additionalObservers }
  } );

  const dispatch = action => {
    dispatched.push( action );
    return action;
  };

  beforeEach( ( ) => {
    dispatched = [];
    global.fetch = jest.fn( ( ) => Promise.resolve( { status: 200 } ) );
    global.$ = jest.fn( selector => ( {
      attr: ( ) => {
        if ( selector.indexOf( "csrf-param" ) >= 0 ) { return "authenticity_token"; }
        if ( selector.indexOf( "csrf-token" ) >= 0 ) { return "tok-xyz"; }
        return null;
      }
    } ) );
  } );

  describe( "addAdditionalObserver", ( ) => {
    it( "POSTs to the observers endpoint with the CSRF token and user id", async ( ) => {
      await addAdditionalObserver( observer )( dispatch, ( ) => stateWith( [] ) );
      expect( global.fetch ).toHaveBeenCalledTimes( 1 );
      const [url, opts] = global.fetch.mock.calls[0];
      expect( url ).toEqual( "/observations/42/observers" );
      expect( opts.method ).toEqual( "post" );
      expect( opts.credentials ).toEqual( "same-origin" );
      expect( opts.body.get( "user_id" ) ).toEqual( "99" );
      expect( opts.body.get( "authenticity_token" ) ).toEqual( "tok-xyz" );
    } );

    it( "optimistically adds the observer to the observation in state", async ( ) => {
      await addAdditionalObserver( observer )( dispatch, ( ) => stateWith( [] ) );
      const setAttrs = dispatched.find( a => a.type === "SET_ATTRIBUTES" );
      expect( setAttrs ).toBeTruthy( );
      const users = setAttrs.attributes.additional_observers.map( ao => ao.user.id );
      expect( users ).toContain( 99 );
    } );
  } );

  describe( "removeAdditionalObserver", ( ) => {
    it( "issues a _method=delete request to the user-specific endpoint", async ( ) => {
      const existing = [{ user: observer }];
      await removeAdditionalObserver( 99 )( dispatch, ( ) => stateWith( existing ) );
      expect( global.fetch ).toHaveBeenCalledTimes( 1 );
      const [url, opts] = global.fetch.mock.calls[0];
      expect( url ).toEqual( "/observations/42/observers/99" );
      expect( opts.body.get( "_method" ) ).toEqual( "delete" );
    } );

    it( "optimistically removes the observer from the observation in state", async ( ) => {
      const existing = [{ user: observer }];
      await removeAdditionalObserver( 99 )( dispatch, ( ) => stateWith( existing ) );
      const setAttrs = dispatched.find( a => a.type === "SET_ATTRIBUTES" );
      expect( setAttrs ).toBeTruthy( );
      expect( setAttrs.attributes.additional_observers ).toEqual( [] );
    } );
  } );
} );
