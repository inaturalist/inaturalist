import React, { PropTypes } from "react";
import TaxonMap from "../../../observations/identify/components/taxon_map";

const TaxonPageMap = ( { taxon } ) => {
  let loading;
  let taxonMap;
  if ( taxon ) {
    const t = Object.assign( { }, taxon, {
      to_styled_s: `<i>${taxon.name}</i>`
    } );
    if ( t.preferred_common_name ) {
      t.common_name = {
        name: t.preferred_common_name
      };
    }
    taxonMap = (
      <TaxonMap
        scrollwheel={false}
        showAllLayer={false}
        minZoom={2}
        gbifLayerLabel={I18n.t( "gbif_network" )}
        taxonLayers={[{
          taxon: t,
          observations: true,
          gbif: { disabled: true },
          places: t.listed_taxa && t.listed_taxa.length > 0,

          // TODO set to false based on taxon response
          ranges: true
        }]}
      />
    );
  } else {
    loading = <span className="loading status">{ I18n.t( "loading" ) }</span>;
  }
  return (
    <div className="TaxonPageMap">
      { loading }
      { taxonMap }
    </div>
  );
};

TaxonPageMap.propTypes = {
  taxon: PropTypes.object
};

export default TaxonPageMap;
