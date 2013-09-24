require 'historyable/version'

require 'active_record'
require 'historyable/change'

module Historyable
  Item = Struct.new(:attribute_name, :association_name)

  extend ActiveSupport::Concern

  included do
    class_attribute :historyable_items, instance_writer: false
  end


  module ClassMethods

    # @param attributes [Array, Symbol]
    def has_history(*attributes)
      self.historyable_items = attributes.map do |attribute|
        attribute_name   = attribute.to_sym
        association_name = attribute.to_s.insert(-1, '_changes').to_sym

        Historyable::Item.new(attribute_name, association_name)
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
        define_historyable_attribute_history_raw(historyable)
        define_historyable_attribute_history(historyable)
        define_historyable_attribute_history?(historyable)
      end

      # Callbacks
      around_save :save_changes
    end


    private

    # attribute_history_raw
    #
    # @example
    #
    #   @user.name_history_raw
    #
    # @return [ActiveRecord::Relation]
    def define_historyable_attribute_history_raw(historyable)
      define_method("#{historyable.attribute_name.to_s}_history_raw") do
        send(historyable.association_name)
          .where(object_attribute: historyable.attribute_name)
          .order('created_at DESC')
          .select(:object_attribute_value, :created_at)
      end
    end

    # attribute_history
    #
    # @example
    #
    #   @user.name_history
    #
    # @return [Array]
    def define_historyable_attribute_history(historyable)
      define_method("#{historyable.attribute_name.to_s}_history") do
        unless instance_variable_get("@#{historyable.attribute_name.to_s}_history".to_sym)
          collection = []

          records = send("#{historyable.attribute_name}_history_raw")
                       .pluck(:object_attribute_value, :created_at)
          records.map do |attribute_value, created_at|
            item = HashWithIndifferentAccess.new
            item[:attribute_value] = attribute_value
            item[:changed_at]      = created_at

            collection << item
          end

          # Sets attribute_history cache
          instance_variable_set("@#{historyable.attribute_name.to_s}_history".to_sym, collection)
          collection
        else
          instance_variable_get("@#{historyable.attribute_name.to_s}_history".to_sym)
        end
      end
    end

    # attribute_history?
    #
    # @example
    #
    #   @user.name_history?
    #
    # @return [Boolean]
    def define_historyable_attribute_history?(historyable)
      define_method("#{historyable.attribute_name.to_s}_history?") do
        send("#{historyable.attribute_name}_history_raw").any?
      end
    end
  end


  private

  # Creates a Change record when an attribute marked as 'historyable' changes
  def save_changes
    changed_historyable_items = historyable_items.select do |historyable|
      changed.include?(historyable.attribute_name.to_s)
    end

    yield # saves the records

    changed_historyable_items.each do |historyable|
      send(historyable.association_name).create(object_attribute: historyable.attribute_name,
                                                object_attribute_value: send(historyable.attribute_name))
      # Expires attribute_history cache
      instance_variable_set("@#{historyable.attribute_name.to_s}_history".to_sym, nil)
    end

    true
  end
end
