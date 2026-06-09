import React from "react";
import type { Meta, StoryObj } from "@storybook/react";
import TaxonThumbnail from "./taxon_thumbnail";
import type { Photo, Taxon } from "../types";

const meta: Meta<typeof TaxonThumbnail> = {
  title: "Shared/TaxonThumbnail",
  component: TaxonThumbnail
};

export default meta;
type Story = StoryObj<typeof TaxonThumbnail>;

const makePhoto = ( seed: string ): Photo => ( {
  id: 1,
  photoUrl: ( ) => `https://picsum.photos/seed/${seed}/400/300`,
  dimensions: ( ) => ( { width: 400, height: 300 } )
} );

const hawk: Taxon = {
  id: 4849,
  name: "Buteo jamaicensis",
  preferred_common_name: "Red-tailed Hawk",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Aves",
  is_active: true,
  defaultPhoto: makePhoto( "hawk" )
};

const fungus: Taxon = {
  id: 54743,
  name: "Amanita muscaria",
  preferred_common_name: "Fly Agaric",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Fungi",
  is_active: true,
  defaultPhoto: makePhoto( "fungus" )
};

const noPhoto: Taxon = {
  id: 1,
  name: "Animalia",
  rank: "kingdom",
  rank_level: 70,
  iconic_taxon_name: "Animalia",
  is_active: true
};

export const Default: Story = {
  args: {
    taxon: hawk
  }
};

export const NoPhoto: Story = {
  args: {
    taxon: noPhoto
  }
};

export const WithCaption: Story = {
  args: {
    taxon: fungus,
    captionForTaxon: ( t: Taxon ) => (
      <div style={{ textAlign: "right", fontSize: "12px", color: "#888" }}>
        { `${t.rank}` }
      </div>
    )
  }
};
