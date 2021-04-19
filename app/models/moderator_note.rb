class ModeratorNote < ActiveRecord::Base
  belongs_to :user
  belongs_to :subject_user, class_name: "User"

  MAX_LENGTH = 750

  validates :body, length: { minimum: 3, maximum: MAX_LENGTH }
  validate :author_is_curator, on: :create

  def editable_by?( editor )
    return false if editor.blank?
    return true if editor.is_admin?
    editor == user
  end

  private
  def author_is_curator
    unless user.is_curator?
      errors.add(:user, :must_be_a_curator)
    end
  end
end
