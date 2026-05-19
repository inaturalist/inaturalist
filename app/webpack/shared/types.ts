// Canonical domain types shared across components.
// Each component should import these rather than redeclaring locally.
// For page-specific fields, use intersection: `Taxon & { extraField?: ... }`.

export interface Photo {
  id: number;
  photoUrl: ( size?: string ) => string;
  attribution?: string;
  dimensions?: ( ) => { width: number; height: number } | null | undefined;
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
  flag_counts?: { unresolved?: number | string; resolved?: number | string };
  photos_locked?: boolean;
  atlas_id?: number;
  // Page-specific fields (conservationStatuses, listed_taxa, listed_taxa_count,
  // conservationStatus, establishment_means, ancestors) are not on the shared type;
  // the page that uses them should intersect: `Taxon & { conservationStatuses?: ... }`.
}

export interface Observation {
  id: number;
  reviewedByCurrentUser?: boolean;
  photo?: ( size?: string ) => string | null;
  photos?: Photo[];
  hasPhotos?: ( ) => boolean;
  hasMedia?: ( ) => boolean;
  hasSounds?: ( ) => boolean;
  user?: Record<string, unknown>;
  taxon?: Taxon;
}

export interface CurrentUser {
  login?: string;
  isAdmin?: boolean;
  isInTestGroup?: ( group: string ) => boolean;
  roles?: string[];
  canViewHelpfulIDTips?: ( ) => boolean;
  privilegedWith?: ( perm: string ) => boolean;
  content_creation_restrictions?: boolean;
}

export interface Config {
  currentUser?: CurrentUser;
}
