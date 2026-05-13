import React from "react";
import type { Meta, StoryObj } from "@storybook/react";
import TaxonPhoto from "./taxon_photo";
import type { Photo, Taxon } from "./taxon_photo";

const meta: Meta<typeof TaxonPhoto> = {
  title: "Shared/TaxonPhoto",
  component: TaxonPhoto,
  args: {
    showTaxonPhotoModal: ( ) => { /* no-op */ }
  }
};

export default meta;
type Story = StoryObj<typeof TaxonPhoto>;

const makePhoto = ( id: number ): Photo => ( {
  id,
  photoUrl: ( _size: string ) => `https://picsum.photos/seed/${id}/400/300`
} );

const hawk: Taxon = {
  id: 4849,
  name: "Buteo jamaicensis",
  preferred_common_name: "Red-tailed Hawk",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Aves",
  is_active: true
};

const fungus: Taxon = {
  id: 54743,
  name: "Amanita muscaria",
  preferred_common_name: "Fly Agaric",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Fungi",
  is_active: true
};

export const Default: Story = {
  args: {
    photo: makePhoto( 1 ),
    taxon: hawk
  }
};

export const ShowTaxon: Story = {
  args: {
    photo: makePhoto( 2 ),
    taxon: hawk,
    showTaxon: true
  }
};

export const ShowTaxonLinked: Story = {
  args: {
    photo: makePhoto( 3 ),
    taxon: hawk,
    showTaxon: true,
    linkTaxon: true
  }
};

export const Fungus: Story = {
  args: {
    photo: makePhoto( 7 ),
    taxon: fungus,
    showTaxon: true,
    linkTaxon: true
  }
};

export const WithObservation: Story = {
  args: {
    photo: makePhoto( 5 ),
    taxon: hawk,
    observation: { id: 12345 },
    showTaxon: true
  }
};
