import React, { PropTypes } from "react";
import SplitTaxon from "./split_taxon";
import UserImage from "./user_image";

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick,
  before,
  controls,
  showMagnifier
} ) => {
  let taxonJSX = I18n.t( "unknown" );
  if ( o.taxon && o.taxon !== null ) {
    taxonJSX = (
      <SplitTaxon taxon={o.taxon} url={`/observations/${o.id}`} />
    );
  }
  let wrapperClass = "thumbnail borderless ObservationsGridItem";
  if ( o.reviewedByCurrentUser ) {
    wrapperClass += " reviewed";
  }
  return (
    <div className={wrapperClass}>
      { before }
      <a
        href={`/observations/${o.id}`}
        style={ {
          backgroundImage: o.photo( ) ? `url( '${o.photo( "medium" )}' )` : ""
        } }
        target="_self"
        className={`photo ${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
        onClick={function ( e ) {
          if ( typeof( onObservationClick ) !== "function" ) {
            return true;
          }
          e.preventDefault();
          onObservationClick( o );
          return false;
        } }
      >
        <i className={ `icon icon-iconic-${"unknown"}`} />
        <i className="sound-icon fa fa-volume-up" />
        { showMagnifier ? (
          <div className="magnifier">
            <i className="fa fa-search"></i>
          </div>
        ) : null }
      </a>
      <div className="caption">
        <UserImage user={ o.user } />
        { taxonJSX }
        <div className="controls">
          { controls }
        </div>
      </div>
    </div>
  );
};

ObservationsGridItem.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func,
  before: PropTypes.element,
  controls: PropTypes.element,
  showMagnifier: PropTypes.bool
};

export default ObservationsGridItem;
