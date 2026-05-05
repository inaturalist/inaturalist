import React, {
  useState, useEffect, useRef, useMemo
} from "react";
import _ from "lodash";

interface CarouselProps {
  items: React.ReactNode[];
  // TODO: can maybe more fancy with interpreting ref type here
  itemRef: React.MutableRefObject<HTMLDivElement>;
  title?: string;
  url?: string;
  description?: string | React.ReactNode;
  noContent?: string;
  className?: string;
}

const calculateChunkSize = (
  carouselSlideRef: React.RefObject<HTMLDivElement>,
  itemRef: React.MutableRefObject<HTMLDivElement>
) => {
  const carouselSlideSize = carouselSlideRef.current?.getBoundingClientRect()?.width;
  const itemSize = itemRef.current?.getBoundingClientRect()?.width;

  return carouselSlideSize && itemSize ? Math.floor( carouselSlideSize / itemSize ) : null;
};

const Carousel = ( {
  title,
  items,
  itemRef,
  url,
  description,
  noContent,
  className
}: CarouselProps ) => {
  const [currentIndex, setCurrentIndex] = useState( 0 );
  const [chunkSize, setChunkSize] = useState<number | null>( 500 );
  const carouselSlideContainerRef = useRef<HTMLDivElement>( null );

  const link = url && (
    <a href={url} className="readmore">
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const hasNav = items.length > 1;

  useEffect( () => {
    window.addEventListener( "resize", ( ) => {
      setChunkSize( calculateChunkSize( carouselSlideContainerRef, itemRef ) );
    } );
  }, [] );

  useEffect( () => {
    setChunkSize( calculateChunkSize( carouselSlideContainerRef, itemRef ) );
  }, [] );

  const slides = useMemo( () => {
    if ( !chunkSize ) return [];

    return _.chunk( items, chunkSize );
  }, [chunkSize] );

  console.log('slides', slides);
  return (
    <div className={`Carousel ${className}`}>
      { title && (
        <h2>
          { title }
          { link }
        </h2>
      ) }
      { description && <p>{ description }</p> }
      { ( slides.length === 0 ) && (
        <p className="text-muted text-center">{ noContent }</p>
      ) }
      <div className="carousel-body">
        { hasNav && (
          <button
            type="button"
            className="btn nav-btn prev-btn"
            disabled={currentIndex === 0}
            onClick={( ) => setCurrentIndex( i => i - 1 )}
            title={I18n.t( "previous_taxon_short" )}
          >
            ❮
          </button>
        ) }
        <div className="carousel-slides" ref={carouselSlideContainerRef}>
          { slides.map( ( slide, index ) => (
            <div
              key={`${_.kebabCase( title )}-carousel-item-${index}`}
              className={`carousel-slide ${index === currentIndex ? "active" : ""}`}
            >
              { slide }
            </div>
          ) ) }
        </div>
        { hasNav && (
          <button
            type="button"
            className="btn nav-btn next-btn"
            disabled={currentIndex >= slides.length - 1}
            onClick={( ) => setCurrentIndex( i => i + 1 )}
            title={I18n.t( "next_taxon_short" )}
          >
            ❯
          </button>
        ) }
      </div>
    </div>
  );
};

Carousel.defaultProps = {
  className: ""
};

export default Carousel;
