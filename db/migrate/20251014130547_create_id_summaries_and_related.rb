# frozen_string_literal: true

class CreateIdSummariesAndRelated < ActiveRecord::Migration[6.1]
  def change
    create_table :id_summaries do | t |
      t.integer    :taxon_id_summary_id
      t.text       :summary
      t.string     :visual_key_group
      t.float      :score
      t.timestamps
    end
    add_index :id_summaries, :taxon_id_summary_id

    create_table :id_summary_references do | t |
      t.integer    :id_summary_id
      t.string     :reference_uuid
      t.string     :reference_source
      t.date       :reference_date
      t.text       :reference_content
      t.integer    :user_id
      t.string     :user_login
      t.timestamps
    end
    add_index :id_summary_references, :id_summary_id

    create_table :id_summary_dqas do | t |
      t.integer    :id_summary_id
      t.integer    :user_id
      t.string     :metric
      t.boolean    :agree, default: true
      t.timestamps
    end
    add_index :id_summary_dqas, :id_summary_id

    create_table :id_summary_reference_dqas do | t |
      t.integer    :id_summary_reference_id
      t.integer    :user_id
      t.string     :metric
      t.boolean    :agree, default: true
      t.timestamps
    end
    add_index :id_summary_reference_dqas, :id_summary_reference_id
  end
end
