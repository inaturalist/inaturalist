require File.dirname(__FILE__) + '/../../../spec/spec_helper'

describe TaxonDescribers::Wikipedia do
  before(:all) do
    load_test_taxa
  end

  it "should describe Calypte anna" do
    TaxonDescribers::Wikipedia.desc(@Calypte_anna).should_not be_blank
  end
end

describe TaxonDescribers::Wikipedia, "clean_html" do
  let(:w) { TaxonDescribers::Wikipedia.new }
  it "should remove data-videopayload" do
    html = <<-HTML
      <div data-videopayload="<div class="mediaContainer"></div>"></div>
    HTML
    w.clean_html(html).should_not match /videopayload/
  end

  it "should remove videopayload" do
    html = <<-HTML
      <div videopayload="<div class="mediaContainer"></div>"></div>
    HTML
    w.clean_html(html).should_not match /videopayload/
  end
end
