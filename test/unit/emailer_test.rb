require File.dirname(__FILE__) + '/../test_helper'

class EmailerTest < ActionMailer::TestCase
  tests Emailer
  fixtures :users, :observations
  
  def test_comment_notification
    observation = observations(:quentin_saw_annas)
    user = users(:ted)
    comment = Comment.create(:user => user, :body => "hey there", :parent => observation)
    mail = Emailer.deliver_comment_notification(comment)
    assert_equal Site.default.noreply_email, mail['reply-to'].to_s
  end
end