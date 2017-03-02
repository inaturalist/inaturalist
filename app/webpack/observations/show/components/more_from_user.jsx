import _ from "lodash";
import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";

const MoreFromUser = ( { observation, observations } ) => {
  if ( !observation || _.isEmpty( observations ) ) { return ( <div /> ); }
  return (
    <div className="MoreFromUser">
      <h3>
        More from { observation.user.login }
        <a href={ `/observations?user_id=${observation.user.login}` }>
          View all
        </a>
      </h3>
      <div className="list">
        { observations.map( o => {
          let taxonJSX = I18n.t( "unknown" );
          if ( o.taxon && o.taxon !== null ) {
            taxonJSX = (
              <SplitTaxon taxon={o.taxon} url={`/observations/${o.id}`} />
            );
          }
          const iconicTaxonName = o.taxon ? o.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
          return (
            <div className="obs" key={ `more-obs-${o.id}` }>
              <div className="photo">
                <a
                  href={`/observations/${o.id}`}
                  style={ {
                    backgroundImage: o.photo( ) ? `url( '${o.photo( "medium" )}' )` : ""
                  } }
                  target="_self"
                  className={`${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
                >
                  <i className={ `icon icon-iconic-${iconicTaxonName}`} />
                  <i className="sound-icon fa fa-volume-up" />
                </a>
              </div>
              <div className="caption">
                { taxonJSX }
              </div>
            </div>
          );
        } ) }
      </div>
    </div>
  );
};

MoreFromUser.propTypes = {
  observation: PropTypes.object,
  observations: PropTypes.array
};

export default MoreFromUser;
