import React, { PropTypes } from "react";

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick
} ) => {
  let taxonJSX;
  if ( o.taxon && o.taxon !== null ) {
    // TODO: make this a separate component
    taxonJSX = (
      <div className="split-taxon">
        <span className={`taxon ${o.taxon.rank} ${o.taxon.iconicTaxonName()} has-com-name`}>
          <a
            href={`/observations/${o.id}`}
            className={`icon icon-iconic-${o.taxon.iconicTaxonName().toString().toLowerCase()}`}
          >
          </a>
          <a className="comname display-name" href={`/observations/${o.id}`}>
            {o.taxon.preferred_common_name}
          </a>
          <a className="sciname" href={`/observations/${o.id}`}>
            {o.taxon.name}
          </a>
        </span>
      </div>
    );
  }
  return (
    <div className="thumbnail borderless ObservationsGridItem">
      <a
        href={`/observations/${o.id}`}
        style={ {
          backgroundImage: o.photo( ) ? `url( '${o.photo( )}' )` : ""
        } }
        target="_self"
        className={`photo ${o.hasMedia( ) ? "" : "iconic"} ${o.hasSound( ) ? "sound" : ""}`}
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
        <a className="userimage" href="" title={o.user.icon_url}>
          <i className="icon-person" />
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
