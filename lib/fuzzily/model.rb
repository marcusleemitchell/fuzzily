module Fuzzily
  module Model
    # Needs fields: trigram, owner_type, owner_id, score
    # Needs index on [owner_type, trigram] and [owner_type, owner_id]

    def self.included(by)
      by.ancestors.include?(ActiveRecord::Base) or raise 'Not included in an ActiveRecord subclass'

      scope_method = ActiveRecord::VERSION::MAJOR == 2 ? :named_scope : :scope

      by.class_eval do
        return if class_variable_defined?(:@@fuzzily_trigram_model)

        belongs_to :owner, :polymorphic => true
        validates_presence_of     :owner
        validates_uniqueness_of   :trigram, :scope => [:owner_type, :owner_id]
        validates_length_of       :trigram, :is => 3
        validates_presence_of     :score
        validates_presence_of     :fuzzy_field

        send scope_method, :for_model,  lambda { |model| { 
          :conditions => { :owner_type => model.kind_of?(Class) ? model.name : model  } 
        }}
        send scope_method, :for_field,  lambda { |field_name| {
          :conditions => { :fuzzy_field => field_name }
        }}
        send scope_method, :with_trigram, lambda { |trigrams| {
          :conditions => { :trigram => trigrams }
        }}

        class_variable_set(:@@fuzzily_trigram_model, true)
      end

      by.extend(ClassMethods)
    end

    module ClassMethods
      # options:
      # - model (mandatory)
      # - field (mandatory)
      # - limit (default 10)
      def matches_for(text, options = {})
        options[:limit] ||= 10
        self.
          scoped(:select => 'owner_id, owner_type, SUM(score) AS total_score').
          scoped(:from => 'trigrams FORCE INDEX(index_for_match)').
          scoped(:group => :owner_id).
          scoped(:order => 'total_score DESC').
          scoped(:limit => options[:limit]).
          with_trigram(text.extend(String).trigrams).
          map(&:owner)
      end

      # override this if you want to specialize the default scope on your trigrams store
      def fuzzily_scope
        self
      end

    end
  end
end

