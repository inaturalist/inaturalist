import React, { PropTypes } from "react";
import SplitTaxon from "./split_taxon";

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick
} ) => {
  let taxonJSX = I18n.t( "unknown" );
  if ( o.taxon && o.taxon !== null ) {
    taxonJSX = (
      <SplitTaxon taxon={o.taxon} url={`/observations/${o.id}`} />
    );
  }
  return (
    <div className="thumbnail borderless ObservationsGridItem">
      <a
        href={`/observations/${o.id}`}
        style={ {
          backgroundImage: o.photo( ) ? `url( '${o.photo( "medium" )}' )` : ""
        } }
        target="_self"
        className={`photo ${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
        onClick={function ( e ) {
          e.preventDefault();
          onObservationClick( o );
          return false;
        } }
      >
        <i className={ `icon icon-iconic-${"unknown"}`} />
        <i className="sound-icon fa fa-volume-up" />
      </a>
      <div className="caption">
        <a
          className="userimage"
          href={`/people/${o.user_id}`}
          title={o.user.login}
          style={ {
            backgroundImage: o.user.icon_url ? `url( '${o.user.icon_url}' )` : ""
          } }
          target="_self"
        >
          <i
            className="icon-person"
            style={ {
              display: o.user.icon_url ? "none" : "inline"
            } }
          />
        </a>
        { taxonJSX }
      </div>
    </div>
  );
};

ObservationsGridItem.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func
};

export default ObservationsGridItem;
