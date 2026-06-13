# frozen_string_literal: true

require "spec_helper"

describe ApplicationHelper, "update_tagline_for" do
  include UsersHelper
  before { enable_has_subscribers }
  after { disable_has_subscribers }

  context "resource is an observation field value" do
    it "states an observation field value was added" do
      without_delay do
        o = Observation.make!
        ofv = ObservationFieldValue.make!( observation: o, user: User.make! )
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{ofv.user.login} added a value for .* to an observation by #{o.user.login}"
        )
      end
    end

    it "states an observation field value was updated" do
      without_delay do
        o = Observation.make!
        ofv = ObservationFieldValue.make!( observation: o, user: User.make! )
        ofv.updater = User.make!
        ofv.save
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{ofv.updater.login} updated a value for .* on an observation by #{o.user.login}"
        )
      end
    end
  end

  ### The following tests are for the code block in the if statement
  ### if notifier.is_a?( Comment ) || notifier.is_a?( Identification ) || update.notification == "mention"
  ### These are highlighted here because it is a section of code in need of refactoring.
  shared_examples_for "a tagliner for adding a comment" do
    it "can state a comment was made to the parent by a different user" do
      without_delay do
        c = Comment.make!( user: User.make!, parent: comment_parent )
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{c.user.login} added a comment to #{parent_text_pattern} by #{comment_parent.user.login}"
        )
      end
    end

    context "i am logged in" do
      let( :me ) { User.make! }
      let( :user_signed_in? ) { true }
      let( :logged_in? ) { true }
      let( :current_user ) { me }

      context "parent is by me" do
        before { comment_parent.user = me }

        it "states a comment was made to its parent by 'you'" do
          without_delay do
            c = Comment.make!( user: User.make!, parent: comment_parent )
            expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
              "#{c.user.login} added a comment to #{parent_text_pattern} by you"
            )
          end
        end
      end

      context "parent and comment are by me, someone else subscribed" do
        before { comment_parent.user = me }
        before { comment_parent.update_subscriptions = [Subscription.make!( user: User.make! )] }
        it "states a comment was made to its parent" do
          without_delay do
            Comment.make!( user: me, parent: comment_parent )
            expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
              "#{me.login} added a comment to #{parent_text_pattern}"
            )
          end
        end
      end
    end
  end

  shared_examples_for "a tagliner for mentioning in a comment" do
    context "i am logged in" do
      let( :me ) { User.make! }
      let( :user_signed_in? ) { true }
      let( :logged_in? ) { true }
      let( :current_user ) { me }

      it "states that you were mentioned in the parent by a different user" do
        without_delay do
          c = Comment.make!( user: User.make!, parent: comment_parent, body: "Mentioning @#{me.login}" )
          expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{c.user.login} mentioned you in #{parent_text_pattern} by #{comment_parent.user.login}"
          )
        end
      end

      context "commenter is same as parent user" do
        let( :commenter ) { User.make! }
        before { comment_parent.user = commenter }
        it "states that you were mentioned in the parent." do
          without_delay do
            c = Comment.make!( user: commenter, parent: comment_parent, body: "Mentioning @#{me.login}" )
            expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
              "#{c.user.login} mentioned you in #{parent_text_pattern}$"
            )
          end
        end
      end

      context "parent is by me" do
        before { comment_parent.user = me }

        it "states that you were mentioned in the parent by 'you'" do
          without_delay do
            c = Comment.make!( user: User.make!, parent: comment_parent, body: "Mentioning @#{me.login}" )
            expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
              "#{c.user.login} mentioned you in #{parent_text_pattern} by you"
            )
          end
        end
      end

      context "parent and comment are both by me" do
        before { comment_parent.user = me }

        it "states that you were mentioned in the parent" do
          without_delay do
            Comment.make!( user: me, parent: comment_parent, body: "Mentioning @#{me.login}" )
            expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
              "#{me.login} mentioned you in #{parent_text_pattern}$"
            )
          end
        end
      end

      context "comment is by me" do
        it "can state a comment was made to its parent by a different user" do
          without_delay do
            c = Comment.make!( user: me, parent: comment_parent, body: "Mentioning @#{me.login}" )
            expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
              "#{c.user.login} mentioned you in #{parent_text_pattern} by #{comment_parent.user.login}"
            )
          end
        end
      end
    end
  end

  context "notifier = comment" do
    context "parent = assessment section" do
      let( :comment_parent ) { AssessmentSection.make! }
      let( :parent_text_pattern ) { "an Assessment Section (.*)" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = atlas" do
      let( :comment_parent ) { Atlas.make! }
      let( :parent_text_pattern ) { "an Atlas" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = complete set" do
      let( :comment_parent ) { CompleteSet.make! }
      let( :parent_text_pattern ) { "a Complete Set" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = flag" do
      let( :comment_parent ) { Flag.make! }
      let( :parent_text_pattern ) { "a Flag" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = listed taxon" do
      let( :comment_parent ) { ListedTaxon.make! }
      let( :parent_text_pattern ) { "a Listed taxon" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = observation" do
      let( :comment_parent ) { Observation.make! }
      let( :parent_text_pattern ) { "an observation" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = observation field" do
      let( :comment_parent ) { ObservationField.make! }
      let( :parent_text_pattern ) { "an Observation field (.*)" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = post" do
      let( :comment_parent ) { Post.make!( parent: Site.make! ) }
      let( :parent_text_pattern ) { "a Journal Post (.*)" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon change" do
      let( :comment_parent ) { TaxonChange.make!( taxon: Taxon.make! ) }
      let( :parent_text_pattern ) { "a taxon change" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon drop" do
      let( :comment_parent ) { TaxonDrop.make!( taxon: Taxon.make! ) }
      let( :parent_text_pattern ) { "a taxon drop" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon link" do
      let( :comment_parent ) { TaxonLink.make!( taxon: Taxon.make! ) }
      let( :parent_text_pattern ) { "a Taxon Link" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon merge" do
      let( :comment_parent ) { TaxonMerge.make!( taxon: Taxon.make!, old_taxa: [Taxon.make!, Taxon.make!] ) }
      let( :parent_text_pattern ) { "a taxon merge" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon split" do
      let( :comment_parent ) { TaxonSplit.make!( taxon: Taxon.make!, new_taxa: [Taxon.make!, Taxon.make!] ) }
      let( :parent_text_pattern ) { "a taxon split" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon stage" do
      let( :comment_parent ) { TaxonStage.make!( taxon: Taxon.make! ) }
      let( :parent_text_pattern ) { "a taxon stage" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end

    context "parent = taxon swap" do
      let( :comment_parent ) { TaxonSwap.make!( taxon: Taxon.make!, old_taxa: [Taxon.make!] ) }
      let( :parent_text_pattern ) { "a taxon swap" }
      it_behaves_like "a tagliner for adding a comment"
      it_behaves_like "a tagliner for mentioning in a comment"
    end
  end

  context "notifier = identification" do
    it "states an identification to an observation was added by another user" do
      without_delay do
        o = Observation.make!
        i = Identification.make!( observation: o, user: User.make! )
        expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
          "#{i.user.login} added an identification to an observation by #{o.user.login}"
        )
      end
    end

    context "i am logged in" do
      let( :me ) { User.make! }
      let( :user_signed_in? ) { true }
      let( :logged_in? ) { true }
      let( :current_user ) { me }

      it "a mention in an identification states that you were mentioned in its observation by another user" do
        without_delay do
          o = Observation.make!
          i = Identification.make!( observation: o, user: User.make!, body: "Mentioning @#{me.login}" )
          expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{i.user.login} mentioned you in an observation by #{o.user.login}"
          )
        end
      end

      context "i made the observation" do
        let( :o ) { Observation.make!( user: me ) }

        it "states an identification to an observation was added by 'you'" do
          without_delay do
            i = Identification.make!( observation: o, user: User.make! )
            expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
              "#{i.user.login} added an identification to an observation by you"
            )
          end
        end

        it "a mention in an identification states that you were mentioned in its observation by 'you'" do
          without_delay do
            i = Identification.make!( observation: o, user: User.make!, body: "Mentioning @#{me.login}" )
            expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
              "#{i.user.login} mentioned you in an observation by you"
            )
          end
        end

        context "i also made the identification" do
          context "someone else is subscribed to the observation" do
            before { o.update_subscriptions = [Subscription.make!( user: User.make! )] }
            it "states an identification was added to an observation only" do
              without_delay do
                Identification.make!( observation: o, user: me )
                expect( update_tagline_for( UpdateAction.last, skip_links: true ) ).to match(
                  "#{me.login} added an identification to an observation"
                )
              end
            end
          end
          it "a mention in an identification states that you were mentioned in its observation" do
            without_delay do
              Identification.make!( observation: o, user: me, body: "Mentioning @#{me.login}" )
              expect(
                update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true )
              ).to match( "#{me.login} mentioned you in an observation$" )
            end
          end
        end
      end
    end
  end

  context "notification = mention" do
    let( :mentioned_u ) { User.make! }

    it "a mention in an observation states that you were mentioned in the observation" do
      without_delay do
        notifier = Observation.make!( user: User.make!, description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in an observation"
          )
      end
    end

    it "a mention in a post states that you were mentioned in the post" do
      without_delay do
        notifier = Post.make!( parent: Site.make!, body: "Hello @#{mentioned_u.login}!" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a Journal Post(.*)"
          )
      end
    end

    it "a mention in a taxon change that you were mentioned in the taxon change" do
      without_delay do
        notifier = TaxonChange.make!( taxon: Taxon.make!, description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon change"
          )
      end
    end

    it "a mention in a taxon drop that you were mentioned in the taxon drop" do
      without_delay do
        notifier = TaxonDrop.make!( taxon: Taxon.make!, description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon drop"
          )
      end
    end

    it "a mention in a taxon merge that you were mentioned in the taxon merge" do
      without_delay do
        notifier = TaxonMerge.make!( taxon: Taxon.make!, old_taxa: [Taxon.make!, Taxon.make!],
          description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon merge"
          )
      end
    end

    it "a mention in a taxon split that you were mentioned in the taxon split" do
      without_delay do
        notifier = TaxonSplit.make!( taxon: Taxon.make!, new_taxa: [Taxon.make!, Taxon.make!],
          description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon split"
          )
      end
    end

    it "a mention in a taxon stage that you were mentioned in the taxon stage" do
      without_delay do
        notifier = TaxonStage.make!( taxon: Taxon.make!, description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon stage"
          )
      end
    end

    it "a mention in a taxon swap that you were mentioned in the taxon swap" do
      without_delay do
        notifier = TaxonSwap.make!( taxon: Taxon.make!, old_taxa: [Taxon.make!],
          description: "Mentioned @#{mentioned_u.login}" )
        expect( update_tagline_for( UpdateAction.where( notification: "mention" )[0], skip_links: true ) ).to match(
            "#{notifier.user.login} mentioned you in a taxon swap"
          )
      end
    end
  end
  ### End tests for
  ### if notifier.is_a?( Comment ) || notifier.is_a?( Identification ) || update.notification == "mention"
end
