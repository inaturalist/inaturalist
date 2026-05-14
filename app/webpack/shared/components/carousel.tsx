import React, {
  useState, useEffect, useRef, useCallback
} from "react";
import css from "./carousel.module.css";

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
  const [activeIndex, setActiveIndex] = useState( 0 );
  const [trackWidth, setTrackWidth] = useState( 0 );
  const itemWidthRef = useRef<number>( 0 );
  const trackRef = useRef<HTMLDivElement>( null );

  const link = url && (
    <a href={url} className={css.carousel__readmore}>
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const allItems = finalItem ? [...items, finalItem] : items;

  useEffect( () => {
    const updateTrackWidth = () => {
      if ( trackRef.current ) setTrackWidth( trackRef.current.getBoundingClientRect().width );
    };
    updateTrackWidth();
    window.addEventListener( "resize", updateTrackWidth );
    return () => window.removeEventListener( "resize", updateTrackWidth );
  }, [] );

  useEffect( () => {
    const measured = itemRef?.current?.getBoundingClientRect().width || 0;
    if ( measured > 0 ) itemWidthRef.current = measured;
  }, [itemRef, items.length] );

  const scrollToIndex = useCallback( ( idx: number ) => {
    const track = trackRef.current;
    if ( !track ) return;
    const item = track.children[idx] as HTMLElement;
    if ( !item ) return;
    const itemLeft = item.getBoundingClientRect().left - track.getBoundingClientRect().left;
    const offset = track.scrollLeft + itemLeft;
    track.scrollTo( { left: offset, behavior: "smooth" } );
  }, [] );

  useEffect( () => {
    const track = trackRef.current;
    let raf: number;
    const handleScroll = () => {
      cancelAnimationFrame( raf );
      raf = requestAnimationFrame( () => {
        if ( !track ) return;
        const trackLeft = track.getBoundingClientRect().left;
        let closest = 0;
        let minDist = Infinity;
        Array.from( track.children ).forEach( ( child, i ) => {
          const dist = Math.abs( child.getBoundingClientRect().left - trackLeft );
          if ( dist < minDist ) { minDist = dist; closest = i; }
        } );
        setActiveIndex( closest );
      } );
    };
    if ( track ) track.addEventListener( "scroll", handleScroll, { passive: true } );
    return ( ) => {
      if ( track ) track.removeEventListener( "scroll", handleScroll );
      cancelAnimationFrame( raf );
    };
  }, [] );

  const visibleCount = trackWidth && itemWidthRef.current
    ? Math.ceil( trackWidth / itemWidthRef.current )
    : allItems.length;

  return (
    <div className={`${css.carousel}${className ? ` ${className}` : ""}`}>
      { title && (
        <div className={css.carousel__title}>
          { title }
          { link }
        </div>
      ) }
      { description && <p>{ description }</p> }
      { allItems.length === 0 && (
        <p className="text-muted text-center">{ noContent }</p>
      ) }
      <div className={css.carousel__body}>
        { allItems.length > 0 && (
          <button
            type="button"
            className={`btn ${css.carousel__navbtn}`}
            disabled={activeIndex === 0}
            onClick={( ) => scrollToIndex( activeIndex - 1 )}
            title={I18n.t( "previous_taxon_short" )}
          >
            ❮
          </button>
        ) }
        <div className={css.carousel__track} ref={trackRef}>
          { allItems.map( ( item, index ) => (
            <div
              key={React.isValidElement( item ) ? String( item.key ) : index}
              className={css.carousel__item}
              style={Math.abs( index - activeIndex ) > visibleCount && itemWidthRef.current
                ? { width: itemWidthRef.current }
                : undefined}
            >
              { Math.abs( index - activeIndex ) <= visibleCount && item }
            </div>
          ) ) }
        </div>
        { allItems.length > 0 && (
          <button
            type="button"
            className={`btn ${css.carousel__navbtn}`}
            disabled={activeIndex >= allItems.length - 1}
            onClick={( ) => scrollToIndex( activeIndex + 1 )}
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
