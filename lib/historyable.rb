require 'historyable/version'

require 'active_record'
require 'historyable/change'

module Historyable
  extend ActiveSupport::Concern

  Item = Struct.new(:attribute_name, :association_name)

  Entry = Struct.new(:attribute_value, :changed_at)

  included do
    class_attribute :historyable_items, instance_writer: false
    attr_accessor   :historyable_cache
  end


  module ClassMethods

    # @param attributes [Array, Symbol]
    def has_history(*attributes)
      self.historyable_items = attributes.map do |attribute|
        attribute_name   = attribute.to_sym
        association_name = "#{attribute}_changes".to_sym

        Item.new(attribute_name, association_name)
      end

      historyable_items.each do |historyable|
        # Associations
        define_historyable_association(historyable)

        # Instance methods
        define_historyable_history_raw(historyable)
        define_historyable_history # Should be defined once only

        define_historyable_attribute_history_raw(historyable)
        define_historyable_attribute_history(historyable)
        define_historyable_attribute_history?(historyable)
      end

      # Callbacks
      around_save :save_changes
    end


    private

    def define_historyable_association(historyable)
      has_many historyable.association_name,
               as:         :item,
               class_name: Change,
               dependent:  :destroy
    end

    # raw_history_of
    #
    # @example
    #
    #   @user.raw_history_of(:name)
    #
    # @return [ActiveRecord::Relation]
    def define_historyable_history_raw(historyable)
      define_method("raw_history_of") do |attribute_name|
        send(historyable.association_name)
          .where(object_attribute: attribute_name)
          .order('created_at DESC')
          .select([:object_attribute_value, :created_at])
      end
    end

    # history_of
    #
    # @example
    #
    #   @user.history_of(:name)
    #
    # @return [Array]
    def define_historyable_history
      define_method("history_of") do |attribute_name|
        self.historyable_cache ||= Hash.new
        historyable_cache[attribute_name] ||= send("raw_history_of", attribute_name).inject([]) do |memo, record|
          entry                 = Entry.new
          entry.attribute_value = record.object_attribute_value
          entry.changed_at      = record.created_at

          memo << entry
        end
      end
    end

    # attribute_history_raw
    #
    # @example
    #
    #   @user.name_history_raw
    #
    # @return [ActiveRecord::Relation]
    def define_historyable_attribute_history_raw(historyable)
      define_method("#{historyable.attribute_name.to_s}_history_raw") do
        send("raw_history_of", historyable.attribute_name)
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
        send("history_of", historyable.attribute_name)
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
      historyable_cache && historyable_cache.delete(historyable.attribute_name)
    end

    true
  end
end
