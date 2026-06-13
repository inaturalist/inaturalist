// Verifies that the FIELDS constant requested when testingApiV2 is active
// includes all fields the observation detail page needs, including
// additional_observers so the AdditionalObservers widget is populated.
import { FIELDS } from "./observation";

describe( "observation duck FIELDS", ( ) => {
  it( "includes additional_observers so the widget is populated in APIv2 mode", ( ) => {
    expect( FIELDS ).toHaveProperty( "additional_observers" );
  } );
} );
