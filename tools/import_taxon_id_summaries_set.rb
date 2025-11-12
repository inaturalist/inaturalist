# frozen_string_literal: true

# Usage:
#   rails runner tools/import_taxon_id_summaries_set.rb \
#     --file /abs/path/to/taxon_summaries.json \
#     [--run-name "Batch run name"] \
#     [--run-generated-at "2025-10-14T12:00:00Z"] \
#     [--run-desc "Seeded from curated examples"] \
#     [--active]
#
# JSON shape (array of taxon summary payloads), e.g.:
# [
#   {
#     "taxon_id": 4756,
#     "taxon_name": "Cathartes aura",
#     "common_name": "Turkey Vulture",
#     "photo_id": 12345,
#     "run_name": "Optional per-taxon override",
#     "run_generated_at": "2025-10-14T12:00:00Z",
#     "run_description": "Optional per-taxon override",
#     "active": true,
#     "items": [
#       {
#         "visual_trait_group": "Coloration",
#         "global_score": 7.33,
#         "summary": "...",
#         "photo_tip": "...",
#         "references": [
#           { "uuid": "...", "source": "...", "user_id": 123, "comment": "...", "url": "..." }
#         ]
#       }
#     ]
#   },
#   ...
# ]
#

require "json"
require "time"
require "optimist"
require "active_model/type"

BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

OPTS = Optimist.options do
  banner <<~HELP
    Import multiple TaxonIdSummaries (and nested IdSummaries) from a single JSON file.

    Usage:
      rails runner tools/import_taxon_id_summaries_set.rb --file FILE [options]
  HELP

  opt :file,             "Path to JSON file (array of taxon payloads)", type: :string, short: "-f", required: true
  opt :run_name,         "Default run name (TaxonIdSummary#run_name) used when JSON payload omits it", type: :string,
    short: "-n"
  opt :run_generated_at, "Default run generated_at (ISO8601)", type: :string
  opt :run_desc,         "Default run description", type: :string
  opt :active,           "Mark each new TaxonIdSummary as active (can be overridden per payload via 'active')",
    type: :boolean, default: false
end

def parse_time!( value, context: )
  return nil if value.nil? || value.to_s.strip == ""
  return value if value.is_a?( Time )

  Time.parse( value.to_s )
rescue ArgumentError
  raise ArgumentError, "Invalid timestamp #{value.inspect} for #{context}"
end

file_path = OPTS[:file]
default_run_name = OPTS[:run_name]
if OPTS[:run_generated_at]
  default_run_generated_at = parse_time!( OPTS[:run_generated_at],
    context: "default run_generated_at" )
end
default_run_desc = OPTS[:run_desc]
default_active = OPTS[:active]

payloads = JSON.parse( File.read( file_path ) )
unless payloads.is_a?( Array )
  raise ArgumentError, "Expected JSON top-level to be an array, got #{payloads.class}"
end

overall_stats = {
  taxon_summaries_created: 0,
  id_summaries_created: 0,
  id_summaries_updated: 0,
  references_created: 0,
  references_updated: 0
}

def deactivate_existing_active_runs!( taxon_id )
  return 0 unless taxon_id

  TaxonIdSummary.where( taxon_id: taxon_id, active: true ).update_all( active: false )
end

payloads.each_with_index do | payload, index |
  context = "payload index=#{index}"

  taxon_id = payload["taxon_id"] || payload["id"]
  raise ArgumentError, "Missing taxon_id for #{context}" if taxon_id.nil?

  taxon_name = payload["taxon_name"] || payload["scientific_name"]
  raise ArgumentError, "Missing taxon_name for taxon_id=#{taxon_id}" if taxon_name.to_s.strip == ""

  taxon_common_name = payload["taxon_common_name"] || payload["common_name"]
  taxon_photo_id = if payload.key?( "taxon_photo_id" )
    payload["taxon_photo_id"]
  else
    payload["photo_id"]
  end
  taxon_group = payload["taxon_group"]

  run_name = payload["run_name"] || default_run_name
  run_generated_at_value = payload.key?( "run_generated_at" ) ? payload["run_generated_at"] : default_run_generated_at
  if run_generated_at_value
    run_generated_at = parse_time!( run_generated_at_value,
      context: "taxon_id=#{taxon_id} run_generated_at" )
  end
  run_description = payload.key?( "run_description" ) ? payload["run_description"] : default_run_desc
  make_active = if payload.key?( "active" )
    BOOLEAN_TYPE.cast( payload["active"] )
  else
    default_active
  end

  unless run_name
    raise ArgumentError, "Missing run_name for taxon_id=#{taxon_id} (provide in JSON payload or via --run-name)"
  end

  items = Array( payload["items"] )

  ActiveRecord::Base.transaction do
    if make_active
      deactivated = deactivate_existing_active_runs!( taxon_id )
      if deactivated.positive?
        puts "Deactivated #{deactivated} existing active TaxonIdSummaries for taxon_id=#{taxon_id}"
      end
    end

    taxon_summary = TaxonIdSummary.create!(
      active: make_active,
      taxon_id: taxon_id,
      taxon_name: taxon_name,
      taxon_common_name: taxon_common_name,
      taxon_photo_id: taxon_photo_id,
      taxon_group: taxon_group,
      run_name: run_name,
      run_generated_at: run_generated_at,
      run_description: run_description
    )

    puts(
      "Created TaxonIdSummary id=#{taxon_summary.id} taxon_id=#{taxon_id} " \
        "active=#{taxon_summary.active} run_name=#{taxon_summary.run_name.inspect}"
    )

    created = 0
    updated = 0
    ref_created = 0
    ref_updated = 0

    items.each do | item |
      visual_key_group = item["visual_trait_group"]
      score            = item["global_score"]
      summary_text     = item["summary"]
      photo_tip        = item["photo_tip"]

      if visual_key_group.to_s.strip == "" || summary_text.to_s.strip == ""
        raise ArgumentError, "Item missing visual_trait_group or summary for taxon_id=#{taxon_id}"
      end

      id_summary = IdSummary.find_or_initialize_by(
        taxon_id_summary_id: taxon_summary.id,
        visual_key_group: visual_key_group,
        summary: summary_text
      )
      id_summary.score = score
      id_summary.photo_tip = photo_tip

      if id_summary.changed?
        id_summary.save!
        if id_summary.previous_changes.key?( "id" )
          created += 1
        else
          updated += 1
        end
      end

      Array( item["references"] ).each do | r |
        reference =
          if r["uuid"].to_s.strip == ""
            IdSummaryReference.find_or_initialize_by(
              id_summary_id: id_summary.id,
              reference_uuid: nil,
              reference_source: r["source"],
              reference_date: r["date"],
              user_id: r["user_id"],
              reference_content: r["comment"]
            )
          else
            IdSummaryReference.find_or_initialize_by( id_summary_id: id_summary.id, reference_uuid: r["uuid"] )
          end

        reference.reference_source  = r["source"]
        reference.reference_date    = r["date"]
        reference.reference_content = r["comment"]
        reference.user_id           = r["user_id"]
        reference.user_login        = nil

        next unless reference.changed?

        reference.save!
        if reference.previous_changes.key?( "id" )
          ref_created += 1
        else
          ref_updated += 1
        end
      end
    end

    puts "  IdSummaries -> created: #{created}, updated: #{updated}"
    puts "  IdSummaryReferences -> created: #{ref_created}, updated: #{ref_updated}"

    overall_stats[:taxon_summaries_created] += 1
    overall_stats[:id_summaries_created] += created
    overall_stats[:id_summaries_updated] += updated
    overall_stats[:references_created] += ref_created
    overall_stats[:references_updated] += ref_updated
  end
end

puts "Processed #{overall_stats[:taxon_summaries_created]} TaxonIdSummaries total."
puts(
  "Totals -> IdSummaries created: #{overall_stats[:id_summaries_created]}, " \
    "updated: #{overall_stats[:id_summaries_updated]}"
)
puts(
  "Totals -> IdSummaryReferences created: #{overall_stats[:references_created]}, " \
    "updated: #{overall_stats[:references_updated]}"
)
