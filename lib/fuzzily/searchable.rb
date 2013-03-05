require 'fuzzily/trigram'

module Fuzzily
  module Searchable
    # fuzzily_searchable <field> [, <field>...] [, <options>]
    def fuzzily_searchable(*fields)
      options = fields.last.kind_of?(Hash) ? fields.pop : {}

      fields.each do |field|
        make_field_fuzzily_searchable(field, options)
      end
    end

    private

    def make_field_fuzzily_searchable(field, options={})
      class_variable_defined?(:"@@fuzzily_searchable_#{field}") and return

      trigram_class_name = options.fetch(:class_name, 'Trigram')
      trigram_association = "trigrams_for_#{field}".to_sym
      update_trigrams_method = "update_fuzzy_#{field}!".to_sym

      has_many trigram_association,
        :class_name => trigram_class_name,
        :as => :owner,
        :conditions => { :fuzzy_field => field.to_s },
        :dependent => :destroy,
        :autosave => true

      singleton_class.send(:define_method, :const_conditions) do 
        if options.has_key?(:scope_field)
          puts "with conditions"
          { :conditions => ["#{options[:scope_field]} #{(options.has_key?(:scope_negate) && options[:scope_negate]) ? 'NOT' : ''} IN (?)",options[:scope_list]] }
        else
          puts "all"
          { :conditions => {} }
        end
      end

      singleton_class.send(:define_method,"find_by_fuzzy_#{field}".to_sym) do |*args|
        case args.size
          when 1 then pattern = args.first ; options = {}
          when 2 then pattern, options = args
          else        raise 'Wrong # of arguments'
        end

        trigram_class_name.constantize.
          scoped(options).
          for_model(self.name).
          for_field(field.to_s).
          matches_for(pattern)
      end

      singleton_class.send(:define_method,"bulk_update_fuzzy_#{field}".to_sym) do
        trigram_class = trigram_class_name.constantize

        self.scoped(:include => trigram_association).find_in_batches(self.const_conditions_from) do |batch|
          inserts = []
          batch.each do |record|
            record.send(field).extend(String).trigrams.each do |trigram|
              inserts << sanitize_sql_array(['(?,?,?,?,?)', self.name, record.id, field.to_s, record.population, trigram])
            end
          end

          trigram_class.transaction do
            batch.each { |record| record.send(trigram_association).delete_all }
            trigram_class.connection.insert(%Q{
              INSERT INTO `#{trigram_class.table_name}`
              (`owner_type`, `owner_id`, `fuzzy_field`, `score`, `trigram`)
              VALUES
              #{inserts.join(", ")}
            })
          end
        end
      end

      define_method update_trigrams_method do
        self.send(trigram_association).delete_all
        self.send(field).extend(String).trigrams.each do |trigram|
          self.send(trigram_association).create!(:score => self.population, :trigram => trigram, :owner_type => self.class.name)
        end
      end

      after_save do |record|
        next unless record.send("#{field}_changed?".to_sym)
        record.send(update_trigrams_method)
      end

      class_variable_set(:"@@fuzzily_searchable_#{field}", true)
      self
    end

  end
end
