# frozen_string_literal: true

require "spec_helper"

describe ControlledTermTaxon do
  it { is_expected.to belong_to( :controlled_term ).inverse_of :controlled_term_taxa }
  it { is_expected.to belong_to( :taxon ).inverse_of :controlled_term_taxa }
  it { is_expected.to validate_presence_of :controlled_term_id }
  it { is_expected.to validate_presence_of :taxon_id }

  describe "reassess_annotations_after_save_later" do
    def reasses_jobs_count
      Delayed::Job.where( "unique_hash LIKE '%reassess_annotations_for_term_id_and_taxon%'" ).count
    end

    it "reassess annotations on create" do
      expect( reasses_jobs_count ).to eq 0
      ControlledTermTaxon.make!
      expect( reasses_jobs_count ).to eq 1
    end

    it "reassess annotations on save" do
      ct = ControlledTermTaxon.make!
      Delayed::Job.delete_all
      expect( reasses_jobs_count ).to eq 0
      ct.update( exception: !ct.exception )
      expect( reasses_jobs_count ).to eq 1
    end

    it "reassess annotations on destroy" do
      ct = ControlledTermTaxon.make!
      Delayed::Job.delete_all
      expect( reasses_jobs_count ).to eq 0
      ct.destroy
      expect( reasses_jobs_count ).to eq 1
    end
  end
end
