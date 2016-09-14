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
      expect(@list).to be_valid
    end
  
    it "should destroy listed taxa where the taxon doesn't match the observation taxon" do
      user = @list.user
      listed_taxon = make_listed_taxon_of_taxon(@child)
      obs = Observation.make!(:user => user, :taxon => @child)
      List.refresh_for_user(user, :taxa => [obs.taxon], :skip_update => true)
      @list.reload
      expect(@list.taxon_ids).to include(@child.id)
  
      new_child = Taxon.make!(:parent => @taxon)
      obs.update_attributes(:taxon => new_child)
      @list.reload
      expect(@list.taxon_ids).not_to include(new_child.id)
  
      LifeList.reload_from_observations(@list)
      @list.reload
      expect(@list.taxon_ids).not_to include(@child.id)
    end

    it "should add taxa from place" do
      p = make_place_with_geom
      o = Observation.make!(:taxon => @child, :latitude => p.latitude, :longitude => p.longitude)
      l = make_life_list_for_taxon(@taxon, :place => p, :user => o.user)
      expect(l.taxa).to be_empty
      LifeList.reload_from_observations(l)
      l.reload
      expect(l.taxa).to include(@child)
    end
  
    def make_listed_taxon_of_taxon(taxon)
      listed_taxon = @list.add_taxon(taxon)
      expect(listed_taxon).to be_valid
      @list.reload
      expect(@list.taxon_ids).to include(taxon.id)
      listed_taxon
    end
  end

  describe "refresh" do
    it "should destroy unobserved taxa if you ask nicely" do
      list = LifeList.make!
      list.taxa << Taxon.make!
      expect(list.taxa.count).to be(1)
      list.refresh(:destroy_unobserved => true)
      list.reload
      expect(list.taxa.count).to be(0)
    end
  end

  describe "refresh_with_observation" do
    before(:each) do
      @parent = Taxon.make!
      @list = LifeList.make!
      @list.build_taxon_rule(@parent)
      @list.save!
      enable_elastic_indexing( Observation )
    end
  
    it "should add new taxa to the list" do
      t = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t)
      expect(@list.taxon_ids).not_to include(t.id)
      LifeList.refresh_with_observation(o)
      @list.reload
      expect(@list.taxon_ids).to include(t.id)
    end

    # a frequent Travis random failure. TODO: figure out why / refactor
    it "should add the species if a subspecies was observed", disabled: ENV["TRAVIS_CI"] do
      species = Taxon.make!(:parent => @parent, :rank => Taxon::SPECIES)
      subspecies = Taxon.make!(:parent => species, :rank => Taxon::SUBSPECIES)
      o = Observation.make!(:user => @list.user, :taxon => subspecies)
      expect(@list.taxon_ids).not_to include(species.id)
      LifeList.refresh_with_observation(o)
      @list.reload
      expect(@list.taxon_ids).to include(species.id)
    end
  
    it "should remove listed taxa that weren't manually added" do
      t = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t)
      expect(@list.taxon_ids).not_to include(t.id)
      LifeList.refresh_with_observation(o)
      @list.reload
      expect(@list.taxon_ids).to include(t.id)
    
      o.destroy
      LifeList.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
      @list.reload
      expect(@list.taxon_ids).not_to include(t.id)
    end
  
    it "should keep listed taxa that were manually added" do
      t = Taxon.make!(:parent => @parent)
      @list.add_taxon(t, :manually_added => true)
      @list.reload
      expect(@list.taxon_ids).to include(t.id)
    
      o = Observation.make!(:user => @list.user, :taxon => t)
      LifeList.refresh_with_observation(o)
      o.destroy
      LifeList.refresh_with_observation(o.id, :created_at => o.created_at, :taxon_id => o.taxon_id, :user_id => o.user_id)
      @list.reload
      expect(@list.taxon_ids).to include(t.id)
    end
  
    it "should keep listed taxa with observations" do
      t = Taxon.make!(:parent => @parent)
      o1 = Observation.make!(:user => @list.user, :taxon => t)
      o2 = Observation.make!(:user => @list.user, :taxon => t)
      LifeList.refresh_with_observation(o2)
    
      o2.destroy
      LifeList.refresh_with_observation(o2.id, :created_at => o2.created_at, :taxon_id => o2.taxon_id, :user_id => o2.user_id)
      @list.reload
      expect(@list.taxon_ids).to include(t.id)
    end
  
    it "should remove taxa when taxon changed" do
      t1 = Taxon.make!(:parent => @parent)
      t2 = Taxon.make!(:parent => @parent)
      o = Observation.make!(:user => @list.user, :taxon => t1)
      LifeList.refresh_with_observation(o)
      expect(@list.taxon_ids).to include(t1.id)
    
      o.update_attributes(:taxon_id => t2.id)
      expect(@list.user.observations.where(taxon_id: t1.id).first).to be_blank
      expect(@list.user.observations.where(taxon_id: t2.id).first).not_to be_blank
      LifeList.refresh_with_observation(o.id, :taxon_id_was => t1.id)
      @list.reload
      expect(@list.taxon_ids).to include(t2.id)
      expect(@list.taxon_ids).not_to include(t1.id)
    end
  end

  describe "update_life_lists_for_taxon" do
    it "should not queue jobs if they already exist" do
      t = Taxon.make!
      l = make_life_list_for_taxon(t)
      Delayed::Job.delete_all
      expect {
        2.times do
          LifeList.update_life_lists_for_taxon(t)
        end
      }.to change(Delayed::Job, :count).by(1)
    end
  end

  describe "places" do
    let(:place) { make_place_with_geom }
    it "should create a rule when set" do
      l = LifeList.make!(:place => place)
      expect(l.rules.detect{|r| r.operator == "observed_in_place?"}).not_to be_blank
    end
    it "should remove the rule when unset" do
      l = LifeList.make!(:place => place)
      l.update_attributes(:place => nil)
      l.reload
      expect(l.rules.detect{|r| r.operator == "observed_in_place?"}).to be_blank
    end
    it "should not allow places without boundaries" do
      l = LifeList.make(:place => Place.make!)
      expect(l).not_to be_valid
    end
    it "should allow taxa observed in place" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude, :longitude => place.longitude)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t)
      expect(lt).to be_valid
    end
    it "should not allow taxa observed outside of the place" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude + 1, :longitude => place.longitude + 1)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t)
      expect(lt).not_to be_valid
    end
    it "should allow manually added taxa that have not been observed" do
      t = Taxon.make!
      o = Observation.make!(:taxon => t, :latitude => place.latitude + 1, :longitude => place.longitude + 1)
      l = LifeList.make!(:user => o.user, :place => place)
      lt = l.add_taxon(t, :manually_added => true)
      expect(lt).to be_valid
    end
  end

  describe "defaults" do
    let(:user) { User.make! }
    it "should set a default title" do
      expect( LifeList.make!(user: user, title: nil).title ).to eq "#{ user.login }'s Life List"
    end

    it "should not set a default description" do
      u = User.make!(login: "UserLogin", name: "UserName")
      expect( LifeList.make!(user: user, description: nil).description ).to be_blank
    end
  end
end
