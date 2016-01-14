require "spec_helper"

describe Admin::DelayedJobsController do
  describe "unlock" do
    before :each do
      u = make_admin
      sign_in u
    end

    it "unlocks delayed jobs" do
      dj = Delayed::Job.create(locked_at: Time.now, locked_by: "someone")
      expect(dj.locked_at).to_not be_nil
      expect(dj.locked_by).to_not be_nil
      get :unlock, id: dj.id
      dj.reload
      expect(dj.locked_at).to be_nil
      expect(dj.locked_by).to be_nil
    end

  end
end
