# frozen_string_literal: true

module HasJournal
  extend ActiveSupport::Concern

  included do
    has_many :journal_posts, class_name: "Post", as: :parent, dependent: :destroy
  end

  def journal_display_name
    case self
    when Project
      title
    when Site
      name
    when User
      login
    else
      t(:journal)
    end
  end

  def journal_owned_by?(user)
    case self
    when Project
      curated_by? user
    when Site
      editable_by? user
    when User
      self == user
    end
  end

  def journal_path
    case self
    when Project
      Rails.application.routes.url_helpers.project_journal_path( slug )
    when Site
      Rails.application.routes.url_helpers.site_posts_path
    when User
      Rails.application.routes.url_helpers.journal_by_login_path( login )
    end
  end

  def journal_slug
    case self
    when Project
      slug
    when Site
      name.to_param
    when User
      login
    end
  end
end
