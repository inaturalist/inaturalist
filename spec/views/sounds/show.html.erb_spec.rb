# frozen_string_literal: true

require "spec_helper"

describe "sounds/show" do
  before {
    assign( :site, create( :site ) )
  }
  describe "LocalSound" do
    login = "tester"
    filename = "pika.mp3"
    let (:owner) { User.make!( login: "tester" ) }
    let (:s) { LocalSound.make!(user: owner, license: Sound::CC0) }
    before {
      s.file = File.open( File.join( Rails.root, "spec", "fixtures", "files", filename ) )
      assign( :sound, s )
    }

    describe "sound player" do
      it "is not rendered if content hidden" do
        mod = make_admin
        moderator_action = ModeratorAction.make!( user: mod, resource: s, action: ModeratorAction::HIDE, created_at: Time.now )
        s.moderator_actions = [moderator_action]

        render

        expect( rendered ).to have_tag( "h3", with: { class: "content-hidden" } )
      end

      it "is rendered if not hidden" do
        render

        expect( rendered ).to have_tag( "div", with: { class: "sound" } )
      end
    end

    describe "attribution" do
      it "renders without edit button for non owner" do
        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :attribution )
          with_tag "td", text: t( 'copyright.no_rights_reserved' )
        end
        expect( rendered ).not_to have_tag( "div", with: { id: :editlicense } )
      end

      it "renders with edit button for owner" do
        sign_in owner

        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :attribution )
          with_tag "td", text: t( 'copyright.no_rights_reserved' )
          with_tag ("td") {
            with_tag "div", id: :editlicense
          }
        end
        sign_out owner
      end
    end

    it "renders uploaded by" do
      render

      expect( rendered ).to have_tag( "tr" ) do
        with_tag "th", text: t( :uploaded_by )
        with_tag "td", text: login
      end
    end

    describe "observations" do
      ### this test works, but there is a warning after running it, so skipping for now.
      # inaturalist/app/helpers/application_helper.rb:360: warning: undefining the 
      # allocator of T_DATA class Redcarpet::Markdown
      # 
      #it "renders them if they exist" do
      #  o = Observation.make!(sounds: [s])
      #  s.observations = [o]
      #  assign( :observations, s.observations )

      #  render

      #  expect( rendered ).to have_tag( "tr" ) do
      #    with_tag "th", text: t( :associated_observations )
      #  end
      #end

      it "does not render them if they do not exist" do 
        render

        expect( rendered ).not_to have_tag( "th", text: t( :associated_observations ) )
      end
    end
  
    describe "sound filename" do
      it "renders if signed in as owner" do
        sign_in owner

        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :filename )
          with_tag "td", text: filename
        end
        sign_out owner
      end

      it "not rendered if signed in as someone else" do
        another_user = User.make!
        sign_in another_user

        render

        expect( rendered ).not_to have_tag( "th", text: t( :filename ))
        expect( rendered ).not_to have_tag( "td", text: filename)
        sign_out another_user
      end
    end

    describe "file url" do
      describe "content hidden" do
        let( :mod ) { make_admin }
        before {
          moderator_action = ModeratorAction.make!( user: mod, resource: s, action: ModeratorAction::HIDE, created_at: Time.now )
          s.moderator_actions = [moderator_action]
        }

        it "does not render file url if not signed in" do      
          render
        
          expect( rendered ).not_to have_tag( "th", text: t( :file_url ) )
        end

        it "does not render file url if signed in as someone else" do
          another_user = User.make!
          sign_in another_user
        
          render
        
          expect( rendered ).not_to have_tag( "th", text: t( :file_url ) )
          sign_out another_user
        end

        it "renders file url as hidden-media-link if signed in as owner" do
          sign_in owner
        
          render
        
          expect( rendered ).to have_tag( "tr" ) do
            with_tag "th", text: t( :file_url )
            with_tag "td" do
              with_tag( "a", with: { class: "hidden-media-link" } )
            end
          end
          sign_out owner
        end

        it "renders file url as hidden-media-link if signed in as curator" do
          curator = make_curator
          sign_in curator
        
          render
        
          expect( rendered ).to have_tag( "tr" ) do
            with_tag "th", text: t( :file_url )
            with_tag "td" do
              with_tag( "a", with: { class: "hidden-media-link" } )
            end
          end
          sign_out curator
        end

        it "does not render file url if modaction is private and signed in as curator" do
          curator = make_curator
          sign_in curator
          moderator_action = ModeratorAction.make!( user: mod, resource: s, action: ModeratorAction::HIDE, created_at: Time.now, private: true )
          s.moderator_actions = [moderator_action]
        
          render
        
          expect( rendered ).not_to have_tag( "th", text: t( :file_url ) )
          sign_out curator
        end

        it "renders file url as hidden-media-link if signed in as admin" do
          admin = make_admin
          sign_in admin
        
          render
        
          expect( rendered ).to have_tag( "tr" ) do
            with_tag "th", text: t( :file_url )
            with_tag "td" do
              with_tag( "a", with: { class: "hidden-media-link" } )
            end
          end
          sign_out admin
        end

        it "renders file url as hidden-media-link if modaction is private and signed in as different admin" do
          admin = make_admin
          sign_in admin
          moderator_action = ModeratorAction.make!( user: mod, resource: s, action: ModeratorAction::HIDE, created_at: Time.now, private: true )
          s.moderator_actions = [moderator_action]
        
          render
        
          expect( rendered ).to have_tag( "tr" ) do
            with_tag "th", text: t( :file_url )
            with_tag "td" do
              with_tag( "a", with: { class: "hidden-media-link" } )
            end
          end
          sign_out admin
        end
      end 

      it "renders file url as regular text if content not hidden" do
        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :file_url )
          with_tag "td", text: s.file.url
        end
      end
    end

    describe "file size" do
      it "renders KB with <1500 KB file" do 
        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :file_size )
          with_tag "td", text: "#{s.file.size / 1000.to_f.round} KB"
        end
      end
    end

    describe "actions" do
      it "shows if owner is logged in" do
        sign_in owner

        render

        expect( rendered ).to have_tag( "tr" ) do
          with_tag "th", text: t( :actions )
        end
        sign_out owner
      end

      it "does not show if non owner is logged in" do
        admin = make_admin
        sign_in admin

        render

        expect( rendered ).not_to have_tag( "th", text: t( :actions ))
        sign_out admin
      end
    end

    describe "flags" do
      it "without them there are no warnings" do
        render

        expect( rendered ).not_to have_tag( "h3", 
          text: t( :heads_up_this_sound_has_been_flagged ) )
        expect( rendered ).not_to have_tag( "div", 
          id: :flaggings_heads_up,
          text: t( :heads_up_this_sound_has_been_flagged ) )
      end

      it "with them there are warnings" do
        f = Flag.make!( flaggable: s, user: User.make! )
        assign( :flags, [f] )

        render 

        expect( rendered ).to have_tag( "h3", 
          text: t( :heads_up_this_sound_has_been_flagged ) )
        expect( rendered ).to have_tag( "div", 
          id: :flaggings_heads_up,
          text: t( :heads_up_this_sound_has_been_flagged ) )
      end

      it "can flag if you are logged in with interacting privileges" do
        interaction_u = User.make!()
        UserPrivilege.make!(user: interaction_u, privilege: UserPrivilege::INTERACTION)
        sign_in interaction_u

        render

        expect( rendered ).to have_tag( "a", 
          text: t( :flag_this_sound ),
          href: new_sound_flag_path(s) )
        sign_out interaction_u
      end

      it "cannot flag if you are not logged in" do
        render

        expect( rendered ).not_to have_tag( "a", 
          text: t( :flag_this_sound ),
          href: new_sound_flag_path(s) )
      end

      it "cannot flag if you are not logged in but without interacting privileges" do
        non_interaction_u = User.make!()
        sign_in non_interaction_u
        
        render

        expect( rendered ).not_to have_tag( "a", 
          text: t( :flag_this_sound ),
          href: new_sound_flag_path(s) )
        sign_out non_interaction_u
      end
    end

    describe "hide/unhide action" do
      describe "hidden content" do
        random_admin = make_admin
        before {
          moderator_action = ModeratorAction.make!( user: random_admin, resource: s, action: ModeratorAction::HIDE, created_at: Time.now )
          s.moderator_actions = [moderator_action]
        }

        it "cannot unhide if you are not logged in" do
        render

        expect( rendered ).not_to have_tag( "a", 
          text: t( :unhide_content ),
          href: hide_sound_path(s) )
        end

        it "cannot unhide if logged in user is not admin" do
          another_user = User.make!
          sign_in another_user

          render

          expect( rendered ).not_to have_tag( "a", 
            text: t( :unhide_content ),
            href: hide_sound_path(s) )
          sign_out another_user
        end

        it "can unhide if content is hidden and logged in as admin" do
          a_diff_admin = make_admin
          sign_in a_diff_admin
          
          render

          expect( rendered ).to have_tag( "a", 
            text: t( :unhide_content ),
            href: hide_sound_path(s) )
          sign_out a_diff_admin
        end
      end

      describe "unhidden content" do
        it "cannot hide if you are not logged in" do
          render

          expect( rendered ).not_to have_tag( "a", 
            text: t( :hide_content ),
            href: hide_sound_path(s) )
        end

        it "cannot hide if logged in user is not admin" do
          another_user = User.make!
          sign_in another_user

          render

          expect( rendered ).not_to have_tag( "a", 
            text: t( :hide_content ),
            href: hide_sound_path(s) )
          sign_out another_user
        end

        it "can hide if content is unhidden and user is admin" do
          sign_in make_admin
          
          render

          expect( rendered ).to have_tag( "a", 
            text: t( :hide_content ),
            href: hide_sound_path(s) )
          sign_out make_admin
        end
      end
    end
  end
end