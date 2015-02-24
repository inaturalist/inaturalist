module ActsAsSpammable::User

  extend ActiveSupport::Concern

  included do
    after_save :suspend_if_spammer
  end

  SPAMMER_COUNT_THRESHOLD = 3
  SPAM_RESEARCH_COUNT_THRESHOLD = 3
  DELETE_SPAM_AFTER = 7.days

  def suspend_if_spammer
    if self.spammer_changed? && self.spammer?
      self.suspend!
    end
  end

  # TODO - what to do when the content is deleted? The spam count will go
  # down and the user will no longer look like a spammer.
  def update_spam_count
    self.spam_count = content_flagged_as_spam.length
    unless self.known_non_spammer?
      if self.spam_count >= User::SPAMMER_COUNT_THRESHOLD
        # anyone with a high spam count is a spammer, except the good eggs
        self.spammer = true
      else
        # spammer === false represents known non-spammers. We want to make
        # sure to maintain that info and set the rest to nil (=unknown)
        self.spammer = nil
      end
    end
    self.save
  end

  def content_flagged_as_spam
    # The FlagsController is apparently the place to check for what
    # models use the acts_as_flaggable module
    Rakismet.spammable_models.map{ |klass|
      # classes have different ways of getting to user, so just do
      # a join and enforce the user_id with a where clause
      if klass == User
        klass.joins(:flags).where({ flags: { flag: Flag::SPAM, resolved: false } })
      else
        klass.joins(:user).where(users: { id: self.id }).
          joins(:flags).where({ flags: { flag: Flag::SPAM, resolved: false } })
      end
    }.compact.flatten.uniq
  end

  def flags_on_spam_content
    content_flagged_as_spam.map do |content|
      content.flags.where(flag: Flag::SPAM)
    end.flatten
  end

  def known_non_spammer?
    # it is important to use spammer and not spammer? since we are allowing
    # nil values to mean unknown, and false to mean non-spammer
    spammer == false
  end

  def unknown_if_spammer?
    ! known_non_spammer? && ! spammer?
  end

  def set_as_non_spammer_if_meets_criteria
    return if known_non_spammer? || spammer?
    count_research_grade_observations =
      observations.has_quality_grade(Observation::RESEARCH_GRADE).count
    if count_research_grade_observations >= User::SPAM_RESEARCH_COUNT_THRESHOLD
      self.spammer = false
      self.save
    end
  end
end
