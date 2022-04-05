require "spec_helper.rb"

def make_task( options = { api_key: "foo" } )
  ft = MushroomObserverImportFlowTask.new
  ft.inputs.build( extra: options[:api_key] ? { api_key: options[:api_key] } : { } )
  ft
end

describe MushroomObserverImportFlowTask do

  it "can create multiple records without different API keys" do
    expect{ make_task( api_key: "onekey" ).save! }.to_not raise_error
    expect{ make_task( api_key: "twokey" ).save! }.to_not raise_error
  end

  it "validates uniqueness of unique_hash" do
    expect{ make_task( api_key: "thekey" ).save! }.to_not raise_error
    expect{ make_task( api_key: "thekey" ).save! }.to raise_error(
      ActiveRecord::RecordInvalid, /queued for import/ )
  end

  it "allows repeat API keys on finished tasks" do
    original = make_task( api_key: "thekey" )
    expect{ original.save! }.to_not raise_error
    expect{ make_task( api_key: "thekey" ).save! }.to raise_error(
      ActiveRecord::RecordInvalid, /queued for import/ )
    original.update( finished_at: Time.now )
    expect{ make_task( api_key: "thekey" ).save! }.to_not raise_error
  end

end
