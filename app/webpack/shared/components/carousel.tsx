import React, {
  useState, useEffect, useRef, useMemo
} from "react";
import _ from "lodash";
import css from "./carousel.module.css";

const s = {
  carousel: css.carousel,
  title: css["carousel__title"],
  body: css["carousel__body"],
  slides: css["carousel__slides"],
  slide: css["carousel__slide"],
  slideActive: css["carousel__slide--active"],
  slideLeft: css["carousel__slide--left"],
  navBtn: css["carousel__nav-btn"]
};

const DEFAULT_CHUNK = 6;
const CAROUSEL_ITEM_GAP = 10; // must match $carousel-item-gap in carousel.module.scss

interface CarouselProps {
  items: React.ReactNode[];
  // TODO: can maybe more fancy with interpreting ref type here
  itemRef: React.MutableRefObject<HTMLDivElement> | null;
  finalItem?: React.ReactNode;
  title?: string;
  url?: string;
  description?: string | React.ReactNode;
  noContent?: string;
  className?: string;
}

const calculateChunkSize = (
  carouselSlideRef: React.RefObject<HTMLDivElement>,
  itemWidth: number
) => {
  const containerWidth = carouselSlideRef.current?.getBoundingClientRect()?.width;
  return containerWidth && itemWidth
    ? Math.floor( ( containerWidth + CAROUSEL_ITEM_GAP ) / ( itemWidth + CAROUSEL_ITEM_GAP ) )
    : DEFAULT_CHUNK;
};

const Carousel = ( {
  title,
  items,
  itemRef,
  finalItem,
  url,
  description,
  noContent,
  className
}: CarouselProps ) => {
  const [currentIndex, setCurrentIndex] = useState( 0 );
  const [chunkSize, setChunkSize] = useState<number | null>( DEFAULT_CHUNK );
  const carouselSlideContainerRef = useRef<HTMLDivElement>( null );
  const itemWidthRef = useRef<number>( 0 );

  const link = url && (
    <a href={url} className="readmore">
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const hasNav = items.length > 1;

  useEffect( () => {
    const observer = new ResizeObserver( () => {
      const measuredWidth = itemRef?.current?.getBoundingClientRect().width || 0;
      if ( measuredWidth > 0 ) {
        itemWidthRef.current = measuredWidth;
      }
      setChunkSize( calculateChunkSize( carouselSlideContainerRef, itemWidthRef.current ) );
    } );
    if ( carouselSlideContainerRef.current ) {
      observer.observe( carouselSlideContainerRef.current );
    }
    return () => observer.disconnect();
  }, [] );

  const slides = useMemo( () => {
    if ( !chunkSize ) return [];

    const s = _.chunk( items, chunkSize );
    if (items.length % chunkSize !== 0 && finalItem) {
      s[s.length - 1].push( finalItem );
    }

    return s;
  }, [chunkSize, items] );

  return (
    <div className={`${s.carousel}${className ? ` ${className}` : ""}`}>
      { title && (
        <h2 className={s.title}>
          { title }
          { link }
        </h2>
      ) }
      { description && <p>{ description }</p> }
      { ( slides.length === 0 ) && (
        <p className="text-muted text-center">{ noContent }</p>
      ) }
      <div className={s.body}>
        { hasNav && (
          <button
            type="button"
            className={`btn ${s.navBtn}`}
            disabled={currentIndex === 0}
            onClick={( ) => setCurrentIndex( i => i - 1 )}
            title={I18n.t( "previous_taxon_short" )}
          >
            ❮
          </button>
        ) }
        <div className={s.slides} ref={carouselSlideContainerRef}>
          { slides.map( ( slide, index ) => (
            <div
              key={`${_.kebabCase( title )}-carousel-item-${index}`}
              className={[
                s.slide,
                index === currentIndex ? s.slideActive : index < currentIndex ? s.slideLeft : ""
              ].filter( Boolean ).join( " " )}
            >
              { slide }
            </div>
          ) ) }
        </div>
        { hasNav && (
          <button
            type="button"
            className={`btn ${s.navBtn}`}
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
