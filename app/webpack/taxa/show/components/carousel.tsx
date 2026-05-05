import React, { useState, useEffect, useRef } from "react";
import _ from "lodash";

interface CarouselProps {
  title: string;
  items: React.ReactNode[];
  url?: string;
  description?: string | React.ReactNode;
  noContent?: string;
  className?: string;
}

const Carousel = ( {
  title,
  items,
  url,
  description,
  noContent,
  className
}: CarouselProps ) => {
  const [currentIndex, setCurrentIndex] = useState( 0 );
  const [sliding, setSliding] = useState( false );
  const wrapperRef = useRef<HTMLDivElement>( null );

  useEffect( ( ) => {
    const wrapper = wrapperRef.current;
    if ( !wrapper ) return;
    const handler = ( ) => {
      const inner = wrapper.querySelector<HTMLElement>( ".carousel-inner" );
      if ( inner ) inner.style.height = "";
      setSliding( false );
    };
    $( ".carousel", wrapper ).on( "slid.bs.carousel", handler );
    return ( ) => {
      $( ".carousel", wrapper ).off( "slid.bs.carousel", handler );
    };
  }, [] );

  const lockHeight = ( ) => {
    const wrapper = wrapperRef.current;
    if ( !wrapper ) return wrapper;
    console.log('wrapper ref', wrapperRef.current);
    console.log('wrapper', wrapperRef.current.getBoundingClientRect() );
    const inner = wrapper.querySelector<HTMLElement>( ".carousel-inner" );
    if ( inner ) inner.style.height = `${inner.getBoundingClientRect( ).height}px`;
    return wrapper;
  };

  const showNext = ( ) => {
    const wrapper = lockHeight( );
    $( ".carousel", wrapper ).carousel( "next" );
    setCurrentIndex( i => i + 1 );
    setSliding( true );
  };

  const showPrev = ( ) => {
    const wrapper = lockHeight( );
    $( ".carousel", wrapper ).carousel( "prev" );
    setCurrentIndex( i => i - 1 );
    setSliding( true );
  };

  const link = url && (
    <a href={url} className="readmore">
      { I18n.t( "view_all_caps" ) }
    </a>
  );

  const descriptionEl = description && <p>{ description }</p>;

  const noContentEl = items.length === 0 && (
    <p className="text-muted text-center">{ noContent }</p>
  );

  const nav = items.length > 1 && (
    <div className="carousel-controls pull-right nav-buttons">
      <button
        type="button"
        className="btn nav-btn prev-btn"
        disabled={currentIndex === 0 || sliding}
        onClick={showPrev}
        title={I18n.t( "previous_taxon_short" )}
      />
      <button
        type="button"
        className="btn nav-btn next-btn"
        disabled={currentIndex >= items.length - 1 || sliding}
        onClick={showNext}
        title={I18n.t( "next_taxon_short" )}
      />
    </div>
  );

  return (
    <div className={`Carousel ${className}`} ref={wrapperRef}>
      { nav }
      <h2>
        { title }
        { link }
      </h2>
      { descriptionEl }
      { noContentEl }
      <div
        className="carousel slide"
        data-ride="carousel"
        data-interval="false"
        data-wrap="false"
        data-keyboard="false"
      >
        <div className="carousel-inner">
          { _.map( items, ( item, index ) => (
            <div
              key={`${_.kebabCase( title )}-carousel-item-${index}`}
              className={`carousel-item-${index} item ${index === 0 ? "active" : ""}`}
            >
              { item }
            </div>
          ) ) }
        </div>
      </div>
    </div>
  );
};

Carousel.defaultProps = {
  className: ""
};

export default Carousel;
