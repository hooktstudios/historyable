require 'historyable/version'

require 'active_record'
require 'historyable/change'

module Historyable
  extend ActiveSupport::Concern

  Item = Struct.new(:attribute_name, :association_name)

  included do
    class_attribute :historyable_items, :historyable_cache, instance_writer: false
  end


  module ClassMethods

    # @param attributes [Array, Symbol]
    def has_history(*attributes)
      self.historyable_cache = ActiveSupport::Cache::MemoryStore.new
      self.historyable_items = attributes.map do |attribute|
        attribute_name   = attribute.to_sym
        association_name = "#{attribute}_changes".to_sym

        Item.new(attribute_name, association_name)
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
          .select([:object_attribute_value, :created_at])
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
        historyable_cache.fetch(historyable.attribute_name) do
          send("#{historyable.attribute_name}_history_raw").inject([]) do |memo, record|
            item = HashWithIndifferentAccess.new
            item[:attribute_value] = record.object_attribute_value
            item[:changed_at]      = record.created_at

            memo << item
          end
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
      historyable_cache.delete(historyable.attribute_name)
    end

    true
  end
end
