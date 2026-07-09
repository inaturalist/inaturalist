import type {
  Photo as BasePhoto, Observation as BaseObservation, Taxon
} from "../../../shared/types";

// A photo with the dimensions accessor the browser-only photo model provides.
export type Photo = BasePhoto & {
  dimensions: () => { width: number; height: number } | null;
};

// An observation that always carries its taxon in this context.
export type Observation = BaseObservation & {
  taxon: Taxon;
};

export interface ObservationPhoto {
  photo: Photo;
  observation: Observation;
}

export interface GroupObject {
  id?: number;
  name?: string;
  label?: string;
  [key: string]: unknown;
}

export interface PhotoGroup {
  groupName: string;
  groupObject: GroupObject;
  observationPhotos: ObservationPhoto[];
}

export interface Grouping {
  param?: string;
  values?: number;
}

export interface Params {
  order_by?: string;
  photo_license?: string;
  quality_grade?: string;
  [key: string]: unknown;
}

export type ShowTaxonPhotoModal = (
  photo: Photo, taxon: Taxon, observation: Observation
) => void;
