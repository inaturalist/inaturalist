require "spec_helper"

describe SiteConfig do

  before :all do
    @config_path = File.join(Rails.root, "config", "config.yml")
    @example_config_path = File.join(Rails.root, "config", "config.yml.example")
  end

  it "loads config.yml by default" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:open).with(@config_path).and_return(
      "test:\n  this_test: passed")
    expect(SiteConfig.load.this_test).to eq "passed"
  end

  it "falls back to loading config.yml.example" do
    allow(File).to receive(:exist?).with(@config_path).and_return(false)
    allow(File).to receive(:exist?).with(@example_config_path).and_return(true)
    allow(File).to receive(:open).with(@example_config_path).and_return(
      "test:\n  this_test: passed")
    expect(SiteConfig.load.this_test).to eq "passed"
  end

  it "raises an error if the config is blank" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:open).with(@config_path).and_return("")
    expect{ SiteConfig.load }.to raise_error("Config is blank")
  end

  it "raises an error if the environment isn't configured" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:open).with(@config_path).and_return(
      "production:\n  this_test: failed")
    expect{ SiteConfig.load }.to raise_error("Config missing environment `test`")
  end

  it "can fetch values with dynamic methods" do
    expect(SiteConfig.site_url).to be_a String
  end

  describe "given site config" do
    before :each do
      allow(File).to receive(:exist?).with(@config_path).and_return(true)
      allow(File).to receive(:open).with(@config_path).and_return("
        test:
          value: itsdefault
        sites:
          inaturalist:
            test:
              value: itsinaturalist
          conabio:
            test:
              value: itsconabio")
    end
    after(:each) { ENV["INATURALIST_SITE_NAME"] = nil }

    it "uses the inaturalist site by default" do
      expect(SiteConfig.load.value).to eq "itsinaturalist"
    end

    it "can set site with ENV variables" do
      ENV["INATURALIST_SITE_NAME"] = "conabio"
      expect(SiteConfig.load.value).to eq "itsconabio"
    end

    it "uses default values for unknown sites" do
      ENV["INATURALIST_SITE_NAME"] = "naturewatch"
      expect(SiteConfig.load.value).to eq "itsdefault"
    end
  end

end
