import React, {
  useState, useEffect, useRef, useMemo, useCallback
} from "react";
import _ from "lodash";
import css from "./carousel.module.css";

const DEFAULT_CHUNK = 6;
const CAROUSEL_ITEM_GAP = 10; // must match --carousel-item-gap in carousel.module.css
const NAV_BTN_WIDTH = 40; // must match width in carousel.module.css

export interface CarouselProps {
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
  availableWidth: number,
  itemWidth: number
) => ( availableWidth && itemWidth
  ? Math.floor( ( availableWidth + CAROUSEL_ITEM_GAP ) / ( itemWidth + CAROUSEL_ITEM_GAP ) )
  : DEFAULT_CHUNK );

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
  const itemWidthRef = useRef<number>( 0 );

  const link = url && (
    <a href={url} className="readmore">
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const hasNav = items.length > 1;

  const handleResize = useCallback( () => {
    const measuredWidth = itemRef?.current?.getBoundingClientRect().width || 0;
    if ( measuredWidth > 0 ) {
      itemWidthRef.current = measuredWidth;
    }
    const navSpace = hasNav ? 2 * ( NAV_BTN_WIDTH + CAROUSEL_ITEM_GAP ) : 0;
    setChunkSize( calculateChunkSize( window.innerWidth - navSpace, itemWidthRef.current ) );
  }, [] );

  useEffect( () => {
    window.addEventListener( "resize", handleResize );
    handleResize();
    return () => window.removeEventListener( "resize", handleResize );
  }, [handleResize] );

  const slides = useMemo( () => {
    if ( !chunkSize ) return [];

    const chunks = _.chunk( items, chunkSize );
    if ( items.length % chunkSize !== 0 && finalItem ) {
      chunks[chunks.length - 1].push( finalItem );
    }

    return chunks;
  }, [chunkSize, items] );

  const itemWidthStyle = {
    "--carousel-slide-count": slides.length || 1,
    ...( chunkSize ? {
      "--carousel-chunk-size": `${chunkSize}`
    } : {} )
  } as React.CSSProperties;

  const trackStyle = {
    transform: slides.length > 1
      ? `translateX(-${( currentIndex / slides.length ) * 100}%)`
      : undefined
  } as React.CSSProperties;

  return (
    <div className={`${css.carousel}${className ? ` ${className}` : ""}`} style={itemWidthStyle}>
      { title && (
        <h2 className={css.carousel__title}>
          { title }
          { link }
        </h2>
      ) }
      { description && <p>{ description }</p> }
      { ( slides.length === 0 ) && (
        <p className="text-muted text-center">{ noContent }</p>
      ) }
      <div className={css.carousel__body}>
        { hasNav && (
          <button
            type="button"
            className={`btn ${css.carousel__navbtn}`}
            disabled={currentIndex === 0}
            onClick={( ) => setCurrentIndex( i => i - 1 )}
            title={I18n.t( "previous_taxon_short" )}
          >
            ❮
          </button>
        ) }
        <div className={css.carousel__slides}>
          <div className={css.carousel__track} style={trackStyle}>
            { slides.map( ( slide, index ) => (
              <div
                key={React.isValidElement( slide[0] ) ? String( slide[0].key ) : index}
                className={css.carousel__slide}
              >
                { Math.abs( index - currentIndex ) <= 1 && slide }
              </div>
            ) ) }
          </div>
        </div>
        { hasNav && (
          <button
            type="button"
            className={`btn ${css.carousel__navbtn}`}
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
