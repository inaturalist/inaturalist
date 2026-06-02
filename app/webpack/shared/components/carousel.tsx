import React, {
  useState, useEffect, useRef, useCallback
} from "react";
import css from "./carousel.module.css";

export interface CarouselProps {
  items: React.ReactNode[];
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
  finalItem,
  url,
  description,
  noContent,
  className = ""
}: CarouselProps ) => {
  const [activeIndex, setActiveIndex] = useState( 0 );
  const [trackWidth, setTrackWidth] = useState( 0 );
  const [itemWidth, setItemWidth] = useState( 0 );
  const trackRef = useRef<HTMLDivElement>( null );

  const link = url && (
    <a href={url} className={css.carousel__readmore}>
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const allItems = finalItem ? [...items, finalItem] : items;

  const measureItemWidth = useCallback( () => {
    if ( !trackRef.current ) return;
    // Measure the first track child with a naturally-derived width (no inline width style,
    // which would indicate a virtualized placeholder using the stale cached value).
    const child = Array.from( trackRef.current.children ).find( el => {
      const h = el as HTMLElement;
      return !h.style.width && h.getBoundingClientRect().width > 0;
    } ) as HTMLElement | undefined;
    if ( child ) {
      const w = child.getBoundingClientRect().width;
      setItemWidth( prev => ( prev !== w ? w : prev ) );
    }
  }, [] );

  useEffect( () => {
    const track = trackRef.current;
    if ( !track ) return () => {};
    const ro = new ResizeObserver( () => {
      const w = track.getBoundingClientRect().width;
      if ( w > 0 ) setTrackWidth( prev => ( prev !== w ? w : prev ) );
      measureItemWidth();
    } );
    ro.observe( track );
    return () => ro.disconnect();
  }, [measureItemWidth] );

  useEffect( () => {
    measureItemWidth();
  }, [measureItemWidth, items] );

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

  const scrollToIndex = useCallback( ( idx: number ) => {
    const track = trackRef.current;
    if ( !track ) return;
    const item = track.children[idx] as HTMLElement;
    if ( !item ) return;
    const itemLeft = item.getBoundingClientRect().left - track.getBoundingClientRect().left;
    const offset = track.scrollLeft + itemLeft;
    track.scrollTo( { left: offset, behavior: "smooth" } );
  }, [] );

  // Until the carousel has been measured, render only a couple items so off-screen
  // CoverImages don't mount and fire network requests on first paint. After ResizeObserver
  // measures the track, visibleCount switches to the real value and placeholders get sized.
  const INITIAL_VISIBLE = 2;
  const visibleCount = trackWidth && itemWidth
    ? Math.ceil( trackWidth / itemWidth )
    : INITIAL_VISIBLE;

  const renderedItems = allItems.map( ( item, index ) => {
    const distFromActive = Math.abs( index - activeIndex );
    return (
      <div
        key={React.isValidElement( item ) ? String( item.key ) : index}
        className={css.carousel__item}
        style={distFromActive > visibleCount && itemWidth
          ? { width: itemWidth }
          : undefined}
      >
        { distFromActive <= visibleCount && item }
      </div>
    );
  } );

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
          { renderedItems }
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

export default Carousel;
