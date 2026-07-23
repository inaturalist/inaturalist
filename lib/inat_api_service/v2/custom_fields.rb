# frozen_string_literal: true

module INatAPIService
  module V2
    module CustomFields
      def self.taxon_core_fields
        {
          id: true,
          name: true,
          rank: true,
          rank_level: true,
          iconic_taxon_name: true,
          preferred_common_name: true,
          is_active: true,
          extinct: true,
          ancestor_ids: true,
          vision: true,
          provisional: true,
          complete_species_count: true,
          observations_count: true,
          complete_rank: true
        }
      end

      def self.taxon_show_fields
        {
          **taxon_core_fields,
          flag_counts: "all",
          listed_taxa_count: true,
          default_photo: {
            url: true
          },
          ancestors: taxon_core_fields,
          children: taxon_core_fields,
          taxon_photos: {
            photo: {
              attribution: true,
              attribution_name: true,
              id: true,
              license_code: true,
              small_url: true,
              medium_url: true,
              original_dimensions: {
                width: true,
                height: true
              },
              url: true
            },
            taxon: taxon_core_fields
          },
          conservation_status: {
            iucn: true,
            status: true,
            description: true,
            url: true,
            authority: true,
            geoprivacy: true,
            user: {
              login: true
            },
            place: {
              display_name: true
            }
          },
          conservation_statuses: {
            iucn: true,
            status: true,
            description: true,
            url: true,
            authority: true,
            geoprivacy: true,
            taxon_id: true,
            taxon_name: true,
            user: {
              login: true
            },
            place: {
              id: true,
              admin_level: true,
              name: true,
              display_name: true
            }
          },
          establishment_means: {
            id: true,
            establishment_means: true,
            place: {
              id: true,
              name: true,
              display_name: true
            }
          },
          listed_taxa: {
            id: true,
            establishment_means: true,
            place: {
              id: true,
              admin_level: true,
              name: true,
              display_name: true
            },
            list: {
              id: true,
              title: true
            }
          }
        }
      end
    end
  end
end
