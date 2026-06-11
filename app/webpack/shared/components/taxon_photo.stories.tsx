import React from "react";
import type { Meta, StoryObj } from "@storybook/react";
import TaxonPhoto from "./taxon_photo";
import type { Photo, Taxon } from "../types";

// TaxonPhoto derives its height from `width`/`height`/`square` plus its parent's
// width (the CoverImage inside is height:100%). It is always rendered inside a
// sized grid cell in the app, so the stories supply explicit dimensions and a
// fixed-width container — without them the image collapses to zero height.
const meta: Meta<typeof TaxonPhoto> = {
  title: "Shared/TaxonPhoto",
  component: TaxonPhoto,
  args: {
    showTaxonPhotoModal: ( ) => { /* no-op */ },
    width: 240,
    height: 240,
    square: true
  },
  decorators: [
    Story => (
      <div style={{ width: 260 }}>
        <Story />
      </div>
    )
  ]
};

export default meta;
type Story = StoryObj<typeof TaxonPhoto>;

const makePhoto = ( id: number ): Photo => ( {
  id,
  photoUrl: ( ) => `https://picsum.photos/seed/${id}/400/300`,
  dimensions: ( ) => ( { width: 400, height: 300 } )
} );

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
    taxon: fungus
  }
};

export const ShowTaxon: Story = {
  args: {
    photo: makePhoto( 2 ),
    taxon: fungus,
    showTaxon: true
  }
};

export const ShowTaxonLinked: Story = {
  args: {
    photo: makePhoto( 3 ),
    taxon: fungus,
    showTaxon: true,
    linkTaxon: true
  }
};
