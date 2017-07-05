import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";

const TaxonPageMap = ( { taxon, bounds, latitude, longitude, zoomLevel } ) => {
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
        showAllLayer={false}
        minZoom={2}
        gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
        taxonLayers={[{
          taxon: t,
          observations: true,
          gbif: { disabled: true },
          places: true,
          ranges: true
        }]}
        minX={ bounds ? bounds.swlng : null }
        minY={ bounds ? bounds.swlat : null }
        maxX={ bounds ? bounds.nelng : null }
        maxY={ bounds ? bounds.nelat : null }
        latitude={ latitude }
        longitude={ longitude }
        zoomLevel={ zoomLevel }
      />
    );
  } else {
    loading = <span className="loading status">{ I18n.t( "loading" ) }</span>;
  }
  return (
    <div className="TaxonPageMap">
      <Grid>
        <Row>
          <Col xs={12}>
            { loading }
            { taxonMap }
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

TaxonPageMap.propTypes = {
  taxon: PropTypes.object,
  bounds: PropTypes.object,
  latitude: PropTypes.number,
  longitude: PropTypes.number,
  zoomLevel: PropTypes.number
};

export default TaxonPageMap;
