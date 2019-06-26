import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

const TaxonPageMap = ( {
  taxon,
  bounds,
  latitude,
  longitude,
  zoomLevel,
  config,
  updateCurrentUser
} ) => {
  let loading;
  let taxonMap;
  const currentUserPrefersMedialessObs = config.currentUser
    && config.currentUser.prefers_medialess_obs_maps;
  if ( taxon ) {
    const t = Object.assign( { }, taxon, {
      forced_name: ReactDOMServer.renderToString(
        <SplitTaxon
          taxon={taxon}
          user={config.currentUser}
          noParens
          iconLink
          url={urlForTaxon( taxon )}
        />
      )
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
          observationLayers: [
            { label: I18n.t( "verifiable_observations" ), verifiable: true },
            {
              label: I18n.t( "observations_without_media" ),
              verifiable: false,
              disabled: !currentUserPrefersMedialessObs,
              onChange: e => updateCurrentUser( { prefers_medialess_obs_maps: e.target.checked } )
            }
          ],
          gbif: { disabled: true },
          places: true,
          ranges: true
        }]}
        minX={bounds ? bounds.swlng : null}
        minY={bounds ? bounds.swlat : null}
        maxX={bounds ? bounds.nelng : null}
        maxY={bounds ? bounds.nelat : null}
        latitude={latitude}
        longitude={longitude}
        zoomLevel={zoomLevel}
        gestureHandling="auto"
        currentUser={config.currentUser}
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
  zoomLevel: PropTypes.number,
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

export default TaxonPageMap;
