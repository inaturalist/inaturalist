module FieldsChangedAt

  extend ActiveSupport::Concern

  included do

    has_many :model_attribute_changes, as: :model, dependent: :destroy

    after_update do
      watched_fields = (self.class)::WATCH_FIELDS_CHANGED_AT
      # make sure the model is watching some fields
      unless watched_fields.blank?
        # loop through the changed fields
        self.changed_attributes.each do |k,v|

          # one of the watched fields has changed
          if watched_fields[ k.to_sym ]
            if c = ModelAttributeChange.where(model: self, field_name: k).first
              # update the date of an existing change record
              c.update_attribute(:changed_at, Time.now)
            else
              # create the first change record for this field
              ModelAttributeChange.create(model: self,
                field_name: k, changed_at: Time.now)
            end
          end

        end
      end
    end

  end
end
