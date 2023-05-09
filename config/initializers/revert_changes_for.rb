# frozen_string_literal: true

module RevertChangesFor
  extend ActiveSupport::Concern

  class_methods do
    #
    # Reverts changes to attributes when the change is basically meaningless,
    # e.g. nil changing to "". Takes a hash, where the attributes are model
    # attributes and the values can be :blank (to revert any change to
    # another blank? value) or an array of values that should be considered
    # equivalent
    #
    def revert_changes_for( changes_to_revert )
      before_validation do
        changes_to_revert.each do | attrib, reversion |
          next unless changes[attrib]

          # revert_changes_for some_text_field: :blank
          revert_change = if reversion == :blank && changes[attrib].first.blank? && changes[attrib].last.blank?
            true
          else
            # revert_changes_for geoprivacy: [nil, "open", ""]
            reversion.is_a?( Array ) &&
              reversion.include?( changes[attrib].first ) &&
              reversion.include?( changes[attrib].last )
          end
          if revert_change
            assign_attributes( attrib => changes[attrib].first )
          end
        end
      end
    end
  end
end

ActiveRecord::Base.include RevertChangesFor
