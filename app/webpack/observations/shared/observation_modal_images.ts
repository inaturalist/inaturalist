interface ModalPhoto {
  hidden?: boolean;
  original_dimensions?: { width: number; height: number };
  photoUrl: ( size: string ) => string;
}

interface ModalObservation<P> {
  user?: { id: number };
  photos: P[];
}

type PhotoConstructor<P> = new ( attrs: object ) => P & { user?: { id: number } };

export default function observationModalImages<P extends ModalPhoto>(
  observation: ModalObservation<P>,
  size: string
) {
  return observation.photos.map( photo => {
    // Moderation UI needs photo.user; keep the constructor for revealHiddenContent's instanceof
    const Photo = photo.constructor as PhotoConstructor<P>;
    return {
      original: photo.hidden ? null : photo.photoUrl( size ),
      zoom: photo.hidden ? null : photo.photoUrl( "original" ),
      thumbnail: photo.photoUrl( "square" ),
      originalDimensions: photo.original_dimensions,
      photo: new Photo( { ...photo, user: observation.user } )
    };
  } );
}
