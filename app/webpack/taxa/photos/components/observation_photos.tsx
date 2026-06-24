import React from "react";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import type { Config } from "../../../shared/types";
import type { ObservationPhoto, ShowTaxonPhotoModal } from "./types";

interface Props {
  observationPhotos?: ObservationPhoto[];
  layout: string;
  showTaxonPhotoModal: ShowTaxonPhotoModal;
  config?: Config;
}

const ObservationPhotos = ( {
  observationPhotos,
  layout,
  showTaxonPhotoModal,
  config = {}
}: Props ) => (
  <>
    { ( observationPhotos || [] ).map( observationPhoto => {
      let itemDim: number | undefined;
      let width: number | undefined;
      if ( layout === "fluid" ) {
        itemDim = 233;
        const dims = observationPhoto.photo.dimensions( );
        width = dims ? ( itemDim / dims.height ) * dims.width : itemDim;
      }
      return (
        <TaxonPhoto
          key={`taxon-photo-${observationPhoto.photo.id}`}
          photo={observationPhoto.photo}
          taxon={observationPhoto.observation.taxon}
          observation={observationPhoto.observation}
          width={width}
          height={itemDim}
          square={layout !== "fluid"}
          showTaxonPhotoModal={( ) => showTaxonPhotoModal(
            observationPhoto.photo,
            observationPhoto.observation.taxon,
            observationPhoto.observation
          )}
          showTaxon
          linkTaxon
          config={config}
        />
      );
    } ) }
  </>
);

export default ObservationPhotos;
