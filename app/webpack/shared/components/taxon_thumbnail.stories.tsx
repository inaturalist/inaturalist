import React from "react";
import type { Meta, StoryObj } from "@storybook/react";
import TaxonThumbnail from "./taxon_thumbnail";
import type { Taxon } from "./taxon_thumbnail";

const meta: Meta<typeof TaxonThumbnail> = {
  title: "Shared/TaxonThumbnail",
  component: TaxonThumbnail
};

export default meta;
type Story = StoryObj<typeof TaxonThumbnail>;

const hawk: Taxon = {
  id: 4849,
  name: "Buteo jamaicensis",
  preferred_common_name: "Red-tailed Hawk",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Aves",
  is_active: true,
  defaultPhoto: {
    photoUrl: ( _size: string ) => "https://picsum.photos/seed/hawk/400/300"
  }
};

const fungus: Taxon = {
  id: 54743,
  name: "Amanita muscaria",
  preferred_common_name: "Fly Agaric",
  rank: "species",
  rank_level: 10,
  iconic_taxon_name: "Fungi",
  is_active: true,
  defaultPhoto: {
    photoUrl: ( _size: string ) => "https://picsum.photos/seed/fungus/400/300"
  }
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

export const WithBadge: Story = {
  args: {
    taxon: fungus,
    badgeText: "3"
  }
};

export const WithBadgeTip: Story = {
  args: {
    taxon: hawk,
    badgeText: "Top",
    badgeTip: "Most observed this month"
  }
};

export const WithOverlay: Story = {
  args: {
    taxon: hawk,
    overlay: <div style={{ padding: "4px 8px", background: "#eee", fontSize: "12px" }}>Observed 42×</div>
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
