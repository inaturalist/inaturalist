class ModelAttributeChange < ApplicationRecord

  belongs_to :model, polymorphic: true

end
