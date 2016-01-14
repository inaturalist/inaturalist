require File.dirname(__FILE__) + '/../spec_helper.rb'

describe LifeList do
  before(:all) do
    DatabaseCleaner.clean_with(:truncation, except: %w[spatial_ref_sys])
  end

  before(:each) { enable_elastic_indexing( Observation, Place ) }
  after(:each) { disable_elastic_indexing( Observation, Place ) }
  describe "reload_from_observations" do
    before(:each) do
      @taxon = Taxon.make!
      @child = Taxon.make!(:parent => @taxon)
      @list = make_life_list_for_taxon(@taxon)
      @list.should be_valid
    end
  
    it "should destroy listed taxa where the taxon doesn't match the observation taxon" do
      user = @list.user
      listed_taxon = make_listed_taxon_of_taxon(@child)
      obs = Observation.make!(:user => user, :taxon => @child)
      List.refresh_for_user(user, :taxa => [obs.taxon], :skip_update => true)
      @list.reload
      @list.taxon_ids.should include(@child.id)
  
      new_child = Taxon.make!(:parent => @taxon)
      obs.update_attributes(:taxon => new_child)
      @list.reload
      @list.taxon_ids.should_not include(new_child.id)
  
      LifeList.reload_from_observations(@list)
      @list.reload
      @list.taxon_ids.should_not include(@child.id)
    end

    it "should add taxa from place" do
      p = make_place_with_geom
      o = Observation.make!(:taxon => @child, :latitude => p.latitude, :longitude => p.longitude)
      l = make_life_list_for_taxon(@taxon, :place => p, :user => o.user)
      l.taxa.should be_empty
      LifeList.reload_from_observations(l)
      l.reload
      l.taxa.should include(@child)
    end
  
    def make_listed_taxon_of_taxon(taxon)
      listed_taxon = @list.add_taxon(taxon)
      listed_taxon.should be_valid
      @list.reload
      @list.taxon_ids.should include(taxon.id)
      listed_taxon
    end
  end

  describe "refresh" do
    it "should destroy unobserved taxa if you ask nicely" do
      list = LifeList.make!
      list.taxa << Taxon.make!
      list.taxa.count.should be(1)
      list.refresh(:destroy_unobserved => true)
      list.reload
      list.taxa.count.should be(0)
    end
  end

  describe "refresh_with_observation" do
    before(:each) do
      @parent = Taxon.make!
      @list = LifeList.make!
      @list.build_taxon_rule(@parent)
      @list.save!
    end
  
    it "should add new taxa to the list" do
      t = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t)
      @list.taxon_ids.should_not include(t.id)
      LifeList.refresh_with_observation(o)
      @list.reload
      @list.taxon_ids.should include(t.id)
    end
  
    it "should add the species if a subspecies was observed" do
      species = Taxon.make!(:parent => @parent, :rank => Taxon::SPECIES)
      subspecies = Taxon.make!(:parent => species, :rank => Taxon::SUBSPECIES)
      o = Observation.make!(:user => @list.user, :taxon => subspecies)
      @list.taxon_ids.should_not include(species.id)
      LifeList.refresh_with_observation(o)
      @list.reload
      @list.taxon_ids.should include(species.id)
    end
  
    it "should remove listed taxa that weren't manually added" do
      t = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t)
      @list.taxon_ids.should_not include(t.id)
      pp @list.taxon_ids
      LifeList.refresh_with_observation(o)
      @list.reload
      pp @t.id
      pp @list.taxon_ids
      @list.taxon_ids.should include(t.id)
    
      o.destroy
      LifeList.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
      @list.reload
      @list.taxon_ids.should_not include(t.id)
    end
  
    it "should keep listed taxa that were manually added" do
      t = Taxon.make!(:parent => @parent)
      @list.add_taxon(t, :manually_added => true)
      @list.reload
      @list.taxon_ids.should include(t.id)
    
      o = Observation.make!(:user => @list.user, :taxon => t)
      LifeList.refresh_with_observation(o)
      o.destroy
      LifeList.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
      @list.reload
      @list.taxon_ids.should include(t.id)
    end
  
    it "should keep listed taxa with observations" do
      t = Taxon.make!(:parent => @parent)
      o1 = Observation.make!(:user => @list.user, :taxon => t)
      o2 = Observation.make!(:user => @list.user, :taxon => t)
      LifeList.refresh_with_observation(o2)
    
      o2.destroy
      LifeList.refresh_with_observation(o2.id, :created_at => o2.created_at, :taxon_id => o2.taxon_id, :user_id => o2.user_id)
      @list.reload
      @list.taxon_ids.should include(t.id)
    end
  
    it "should remove taxa when taxon changed" do
      t1 = Taxon.make!(:parent => @parent)
      t2 = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t1)
      LifeList.refresh_with_observation(o)
      @list.taxon_ids.should include(t1.id)
    
      o.update_attributes(:taxon_id => t2.id)
      @list.user.observations.where(taxon_id: t1.id).first.should be_blank
      @list.user.observations.where(taxon_id: t2.id).first.should_not be_blank
      LifeList.refresh_with_observation(o.id, :taxon_id_was => t1.id)
      @list.reload
      @list.taxon_ids.should include(t2.id)
      @list.taxon_ids.should_not include(t1.id)
    end
  end

  describe "update_life_lists_for_taxon" do
    it "should not queue jobs if they already exist" do
      t = Taxon.make!
      l = make_life_list_for_taxon(t)
      Delayed::Job.delete_all
      lambda {
        2.times do
          LifeList.update_life_lists_for_taxon(t)
        end
      }.should change(Delayed::Job, :count).by(1)
    end
  end

  describe "places" do
    let(:place) { make_place_with_geom }
    it "should create a rule when set" do
      l = LifeList.make!(:place => place)
      l.rules.detect{|r| r.operator == "observed_in_place?"}.should_not be_blank
    end
    it "should remove the rule when unset" do
      l = LifeList.make!(:place => place)
      l.update_attributes(:place => nil)
      l.reload
      l.rules.detect{|r| r.operator == "observed_in_place?"}.should be_blank
    end
    it "should not allow places without boundaries" do
      l = LifeList.make(:place => Place.make!)
      l.should_not be_valid
    end
    it "should allow taxa observed in place" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude, :longitude => place.longitude)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t)
      lt.should be_valid
    end
    it "should not allow taxa observed outside of the place" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude + 1, :longitude => place.longitude + 1)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t)
      lt.should_not be_valid
    end
    it "should allow manually added taxa that have not been observed" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude + 1, :longitude => place.longitude + 1)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t, :manually_added => true)
      lt.should be_valid
    end
  end

  describe "defaults" do
    let(:user) { User.make! }
    it "should set a default title" do
      LifeList.make!(user: user, title: nil).
        title.should eq "#{ user.login }'s Life List"
    end

    it "should set a default description" do
      u = User.make!(login: "UserLogin", name: "UserName")
      LifeList.make!(user: user, description: nil).
        description.should eq "Every species seen by #{ user.login }"
    end
  end
end
