require "spec_helper"

describe SiteConfig do

  before :all do
    @config_path = File.join(Rails.root, "config", "config.yml")
    @example_config_path = File.join(Rails.root, "config", "config.yml.example")
  end

  it "loads config.yml by default" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:read).with(@config_path).and_return(
      "test:\n  this_test: passed")
    expect(SiteConfig.load.this_test).to eq "passed"
  end

  it "falls back to loading config.yml.example" do
    allow(File).to receive(:exist?).with(@config_path).and_return(false)
    allow(File).to receive(:exist?).with(@example_config_path).and_return(true)
    allow(File).to receive(:read).with(@example_config_path).and_return(
      "test:\n  this_test: passed")
    expect(SiteConfig.load.this_test).to eq "passed"
  end

  it "raises an error if the config is blank" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:read).with(@config_path).and_return("")
    expect{ SiteConfig.load }.to raise_error("Config is blank")
  end

  it "raises an error if the environment isn't configured" do
    allow(File).to receive(:exist?).with(@config_path).and_return(true)
    allow(File).to receive(:read).with(@config_path).and_return(
      "production:\n  this_test: failed")
    expect{ SiteConfig.load }.to raise_error("Config missing environment `test`")
  end

end
