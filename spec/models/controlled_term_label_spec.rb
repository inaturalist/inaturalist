# frozen_string_literal: true

require "spec_helper"

describe ControlledTermLabel do
  it { is_expected.to belong_to :controlled_term }
  it { is_expected.to belong_to( :valid_within_taxon ).with_foreign_key( :valid_within_clade ).class_name "Taxon" }
  it { is_expected.to validate_presence_of( :definition ).on( :create ) }
end
