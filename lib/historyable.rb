require "historyable/version"

require "active_record"
require "historyable/change"

module Historyable
  class Item < Struct.new(:attribute, :association_name); end

  extend ActiveSupport::Concern

  included do
    class_attribute :historyable_items, instance_writer: false
  end


  module ClassMethods

    # @param attributes [Array, Symbol]
    def has_history(*attributes)
      self.historyable_items = attributes.map do |attribute|
        attribute        = attribute.to_sym
        association_name = attribute.to_s.insert(-1, '_changes').to_sym

        Historyable::Item.new(attribute, association_name)
      end

      # Associations
      historyable_items.each do |historyable|
        has_many historyable.association_name,
                 as:         :item,
                 class_name: '::Change',
                 dependent:  :destroy
      end


      # Instance methods
      historyable_items.each do |historyable|

        # raw_attribute_history
        #
        # @return [ActiveRecord::Relation]
        define_method("raw_#{historyable.attribute.to_s}_history") do
          send(historyable.association_name)
            .where(object_attribute: historyable.attribute)
            .order('created_at DESC')
            .select(:object_attribute_value, :created_at)
        end


        # attribute_history
        #
        # @return [Array]
        define_method("#{historyable.attribute.to_s}_history") do
          unless instance_variable_get("@#{historyable.attribute.to_s}_history".to_sym)
            array = []

            records = send("raw_#{historyable.attribute}_history")
                         .pluck(:object_attribute_value, :created_at)
            records.map do |attribute_value, created_at|
              hash = HashWithIndifferentAccess.new
              hash[:attribute_value] = attribute_value
              hash[:changed_at]      = created_at

              array << hash
            end

            # Sets attribute_history cache
            instance_variable_set("@#{historyable.attribute.to_s}_history".to_sym, array)
            array
          else
            instance_variable_get("@#{historyable.attribute.to_s}_history".to_sym)
          end
        end
      end


      # Callbacks
      around_save :save_changes
    end
  end


  private

  # Creates a Change record when an attribute marked as 'historyable' changes
  def save_changes
    changed_historyable_items = historyable_items.select do |historyable|
      changed.include?(historyable.attribute.to_s)
    end

    yield # saves the records

    changed_historyable_items.each do |historyable|
      send(historyable.association_name).create(object_attribute: historyable.attribute,
                                                object_attribute_value: send(historyable.attribute))
      # Expires attribute_history cache
      instance_variable_set("@#{historyable.attribute.to_s}_history".to_sym, nil)
    end

    true
  end
end
