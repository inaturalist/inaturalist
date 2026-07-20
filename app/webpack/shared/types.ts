// Canonical domain types shared across components.
// Each component should import these rather than redeclaring locally.
// For page-specific fields, use intersection: `Taxon & { extraField?: ... }`.

export interface Photo {
  id: number;
  // Prototype methods on the inaturalistjs model instance — always present.
  photoUrl: ( size?: string ) => string;
  dimensions: ( ) => { width: number; height: number } | null | undefined;
  // Passthrough data field — present only when the payload includes it.
  attribution?: string;
}

// Photo as it appears on raw API responses (no model methods).
export interface RawPhoto {
  medium_url: string;
  square_url: string;
}

export interface Taxon {
  id: number;
  name: string;
  rank?: string;
  rank_level?: number;
  preferred_common_name?: string;
  iconic_taxon_name?: string;
  is_active?: boolean;
  ancestor_ids?: number[];
  // Photo on a model instance vs. raw API payload — different field names.
  defaultPhoto?: Photo;
  default_photo?: RawPhoto;
  // Fields surfaced on most taxon-related views.
  complete_species_count?: number;
  flag_counts?: { unresolved?: number; resolved?: number };
  photos_locked?: boolean;
  atlas_id?: number;
  // Page-specific fields (conservationStatuses, listed_taxa, listed_taxa_count,
  // conservationStatus, establishment_means, ancestors) are not on the shared type;
  // the page that uses them should intersect: `Taxon & { conservationStatuses?: ... }`.
}

export interface User {
  id: number;
  login?: string;
  name?: string;
  preferences?: Record<string, unknown>;
  observations_count?: number;
}

export interface Observation {
  id: number;
  // Prototype methods on the inaturalistjs model instance — always present.
  photo: ( size?: string ) => string | null;
  hasPhotos: ( ) => boolean;
  hasMedia: ( ) => boolean;
  hasSounds: ( ) => boolean;
  // Passthrough data fields — present only when the payload includes them.
  reviewedByCurrentUser?: boolean;
  photos?: Photo[];
  user?: User;
  taxon?: Taxon;
}

export interface CurrentUser {
  // Always set by the CurrentUser model constructor / prototype.
  isAdmin: boolean;
  isCurator: boolean;
  loggedIn: boolean;
  isInTestGroup: ( group: string ) => boolean;
  canNominateHelpfulIDTips: ( ) => boolean;
  canNominateIdentification: ( identification: object ) => boolean;
  canUnnominateIdentification: ( identification: object ) => boolean;
  privilegedWith: ( perm: string ) => boolean;
  // Passthrough data fields — present only when the payload includes them.
  id?: number;
  login?: string;
  roles?: string[];
  content_creation_restrictions?: boolean;
}

export interface Config {
  currentUser?: CurrentUser;
}

export interface Place {
  id: number;
  display_name: string;
  [key: string]: unknown;
}

// Controlled annotation vocabulary (attributes and their values).
export interface ControlledAttribute {
  id: number;
  label: string;
}

export interface ControlledValue {
  id: number;
  label: string;
}

export interface TermValue {
  controlled_attribute: ControlledAttribute;
  controlled_value: ControlledValue;
}
