import observationModalImages from "./observation_modal_images";

class FakePhoto {
  id!: number;

  hidden?: boolean;

  user?: { id: number };

  original_dimensions?: { width: number; height: number };

  constructor( attrs: Partial<FakePhoto> ) {
    Object.assign( this, attrs );
  }

  photoUrl( size: string ) {
    return `${this.id}-${size}`;
  }
}

const user = { id: 1 };

describe( "observationModalImages", ( ) => {
  it( "builds gallery items at the requested size", ( ) => {
    const photo = new FakePhoto( { id: 5, original_dimensions: { width: 10, height: 20 } } );
    const [image] = observationModalImages( { user, photos: [photo] }, "large" );
    expect( image ).toMatchObject( {
      original: "5-large",
      zoom: "5-original",
      thumbnail: "5-square",
      originalDimensions: { width: 10, height: 20 }
    } );
  } );

  it( "attaches the observer to the photo without losing its class", ( ) => {
    const [image] = observationModalImages( { user, photos: [new FakePhoto( { id: 5 } )] }, "medium" );
    expect( image.photo ).toBeInstanceOf( FakePhoto );
    expect( image.photo.user ).toBe( user );
  } );

  it( "withholds full-size urls for hidden photos", ( ) => {
    const [image] = observationModalImages(
      { user, photos: [new FakePhoto( { id: 5, hidden: true } )] },
      "medium"
    );
    expect( image ).toMatchObject( { original: null, zoom: null, thumbnail: "5-square" } );
  } );
} );
