class Change < ActiveRecord::Base
  belongs_to :historyable, polymorphic: true
  serialize :object_attribute_value
end
