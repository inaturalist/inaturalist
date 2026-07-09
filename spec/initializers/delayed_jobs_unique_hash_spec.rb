# frozen_string_literal: true

require "spec_helper"

describe "Delayed::Jobs::unique_hash" do
  it "allows a unique_hash to be set" do
    expect( Delayed::Job.count ).to eq 0
    User.delay( unique_hash: "itworks" ).find( 1 )
    expect( Delayed::Job.count ).to eq 1
    expect( Delayed::Job.first.unique_hash ).to eq "itworks"
  end

  it "enforces unique_hash uniqueness" do
    expect( Delayed::Job.count ).to eq 0
    User.delay( unique_hash: "first!" ).find( 1 )
    User.delay( unique_hash: "first!" ).find( 2 )
    User.delay( unique_hash: "third" ).find( 3 )
    expect( Delayed::Job.count ).to eq 2
    expect( Delayed::Job.all[0].unique_hash ).to eq "first!"
    expect( Delayed::Job.all[1].unique_hash ).to eq "third"
  end

  it "catches DB uniqueness validation failures and treats them as rails validation errors" do
    expect( Delayed::Job.count ).to eq 0
    User.delay( unique_hash: "first!" ).find( 1 )
    expect( Delayed::Job.count ).to eq 1
    expect( Delayed::Job.all[0].unique_hash ).to eq "first!"

    # without the custom save and rescuing of UniqueViolation, this would
    # raise an error becuase the DB would fail to save the record due to
    # the uniqueness constraint on this column in the DB. We are rescuing
    # that exception, and marking the instance as invalid - the same as if
    # the rails `validates_uniqueness_of` validation were the one to catch
    # the uniqueness failure
    second_job = Delayed::Job.create( unique_hash: "first!" )
    expect do
      # skip validations to skip the `validates_uniqueness_of :unique_hash`
      # validation - attempting to simulate a race condition where that
      # validation passes, but another record is added to the DB before this
      # one can be actually saved
      second_job.save( validate: false )
    end.not_to raise_error
    expect( second_job ).not_to be_valid
    # when the UniqueViolation is caught, an attribute `unique_hash_taken` is
    # set so that if .valid? is called again on the instance, we will already
    # know its unique_hash is not unique w/o needing to query the DB again
    expect( second_job.unique_hash_taken ).to be true
    expect( second_job.errors[:unique_hash] ).not_to be_empty
  end

  it "does not leave open transactions in a failed state" do
    User.delay( unique_hash: "first!" ).find( 1 )
    second_job = Delayed::Job.new( unique_hash: "first!" )
    # many jobs are enqueued from model callbacks, i.e. inside an open
    # transaction. When an INSERT violates a unique index, Postgres aborts
    # the entire transaction. This is checking that after hitting a DB
    # unique index violation, the open transaction can still process
    # queries, and does not raise a PG::InFailedSqlTransaction error
    ActiveRecord::Base.transaction do
      expect( second_job.save( validate: false ) ).to be false
      expect( second_job.unique_hash_taken ).to be true
      expect do
        Delayed::Job.count
      end.not_to raise_error
    end
  end
end
