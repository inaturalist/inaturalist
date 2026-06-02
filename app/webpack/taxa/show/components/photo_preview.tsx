import React, { useState } from "react";
import CoverImage from "../../../shared/components/cover_image";
import { urlForTaxonPhotos } from "../../shared/util";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import type {
  Photo, Taxon, Observation, Config
} from "../../../shared/types";

const GRID_THUMBNAIL_HEIGHT = 196.5;
const GALLERY_THUMBNAIL_HEIGHT = 98;

interface TaxonPhotoEntry {
  photo: Photo;
  taxon: Taxon;
}

interface Props {
  taxon: Taxon;
  taxonPhotos: TaxonPhotoEntry[];
  layout?: string;
  showTaxonPhotoModal?: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  showPhotoChooserModal?: ( ) => void;
  showNewTaxon?: ( taxon: Taxon ) => void;
  config?: Config;
}

interface NoPhotosProps {
  showPhotoChooserModal?: ( ) => void;
  config?: Config;
}

const NoPhotos = ( { showPhotoChooserModal, config = {} }: NoPhotosProps ) => {
  const { currentUser } = config;
  return (
    <div className="PhotoPreview no-content text-center text-muted">
      <div>
        <h3>
          { I18n.t( "this_taxon_has_no_default_photo" ) }
        </h3>
        { !currentUser?.content_creation_restrictions && (
          <button
            type="button"
            className="btn btn-primary"
            onClick={( ) => showPhotoChooserModal?.( )}
          >
            { I18n.t( "add_one_now" ) }
          </button>
        ) }
      </div>
    </div>
  );
};

interface GridPreviewProps {
  taxon: Taxon;
  taxonPhotos: TaxonPhotoEntry[];
  showTaxonPhotoModal?: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  showNewTaxon?: ( taxon: Taxon ) => void;
  config?: Config;
}

const GridPreview = ( {
  taxon,
  taxonPhotos: taxonPhotosProp,
  showTaxonPhotoModal,
  showNewTaxon,
  config = {}
}: GridPreviewProps ) => {
  const taxonPhotos = taxonPhotosProp.slice( 0, 8 );
  const displayPhotos = taxonPhotos.length === 1 ? [] : taxonPhotos;
  return (
    <div className="PhotoPreview grid">
      <div className="foreground-container">
        <ul className="plain others">
          { displayPhotos.map( taxonPhoto => (
            <li key={`taxon-photo-${taxonPhoto.taxon.id}-${taxonPhoto.photo.id}`}>
              <TaxonPhoto
                photo={taxonPhoto.photo}
                height={GRID_THUMBNAIL_HEIGHT}
                taxon={taxonPhoto.taxon}
                size="medium"
                square={false}
                showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
                className="photoItem"
                showTaxon
                linkTaxon={taxonPhoto.taxon.id !== taxon.id}
                onClickTaxon={newTaxon => showNewTaxon?.( newTaxon )}
                config={config}
              />
            </li>
          ) ) }
          <li className="viewmore">
            <a
              href={urlForTaxonPhotos( taxon )}
              style={{ height: `${GRID_THUMBNAIL_HEIGHT}px` }}
            >
              <span className="inner">
                <span>{ I18n.t( "view_more" ) }</span>
                <i className="fa fa-arrow-circle-right" />
              </span>
            </a>
          </li>
        </ul>
      </div>
    </div>
  );
};

interface GalleryPreviewProps {
  taxon: Taxon;
  taxonPhotos: TaxonPhotoEntry[];
  showTaxonPhotoModal?: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  config?: Config;
}

const GalleryPreview = ( {
  taxon,
  taxonPhotos: taxonPhotosProp,
  showTaxonPhotoModal,
  config = {}
}: GalleryPreviewProps ) => {
  const [currentPhotoIdx, setCurrentPhotoIdx] = useState<number>( 0 );
  const taxonPhotos = taxonPhotosProp.slice( 0, 5 );
  const displayPhotos = taxonPhotos.length === 1 ? [] : taxonPhotos;
  const currentEntry = taxonPhotos[currentPhotoIdx];
  const dims = currentEntry?.photo.dimensions( );
  const ratio = ( dims && dims.height ) ? dims.width / dims.height : 1;
  const backgroundSize = ratio > 1.3 ? "contain" : "cover";
  const currentPhotoHeight = backgroundSize === "contain" ? 500 : 590;

  const bgImage = backgroundSize === "contain" && currentEntry ? (
    <div
      className="photo-bg"
      style={{ backgroundImage: `url('${currentEntry.photo.photoUrl( "small" )}')` }}
    />
  ) : null;

  const currentPhoto = currentEntry ? (
    <TaxonPhoto
      taxon={taxon}
      photo={currentEntry.photo}
      size="large"
      showTaxonPhotoModal={showTaxonPhotoModal ?? ( ( ) => undefined )}
      height={currentPhotoHeight}
      backgroundSize={backgroundSize}
      config={config}
    />
  ) : null;

  return (
    <div className={`PhotoPreview gallery${backgroundSize === "cover" ? " cover-bg" : ""}`}>
      { bgImage }
      <div className="foreground-container">
        { currentPhoto }
        <ul className="plain others">
          { displayPhotos.map( ( taxonPhoto, idx ) => (
            <li key={`taxon-photo-${taxonPhoto.taxon.id}-${taxonPhoto.photo.id}`}>
              <a
                className="photoItem"
                href={taxonPhoto.photo.photoUrl( )}
                aria-label={I18n.t( "view_photo" )}
                onClick={e => {
                  e.preventDefault( );
                  setCurrentPhotoIdx( idx );
                  return false;
                }}
              >
                <CoverImage
                  src={taxonPhoto.photo.photoUrl( "small" )}
                  low={taxonPhoto.photo.photoUrl( "small" )}
                  height={GALLERY_THUMBNAIL_HEIGHT}
                />
              </a>
            </li>
          ) ) }
          <li className="viewmore">
            <a href={urlForTaxonPhotos( taxon )}>
              <span className="inner">
                <span>{ I18n.t( "view_more" ) }</span>
                <i className="fa fa-arrow-circle-right" />
              </span>
            </a>
          </li>
        </ul>
      </div>
    </div>
  );
};

const PhotoPreview = ( {
  taxon,
  taxonPhotos,
  layout,
  showTaxonPhotoModal,
  showPhotoChooserModal,
  showNewTaxon,
  config = {}
}: Props ) => {
  if ( taxonPhotos.length === 0 ) {
    return (
      <NoPhotos
        showPhotoChooserModal={showPhotoChooserModal}
        config={config}
      />
    );
  }
  if ( layout === "grid" ) {
    return (
      <GridPreview
        taxon={taxon}
        taxonPhotos={taxonPhotos}
        showTaxonPhotoModal={showTaxonPhotoModal}
        showNewTaxon={showNewTaxon}
        config={config}
      />
    );
  }
  return (
    <GalleryPreview
      taxon={taxon}
      taxonPhotos={taxonPhotos}
      showTaxonPhotoModal={showTaxonPhotoModal}
      config={config}
    />
  );
};

export default PhotoPreview;
