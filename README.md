# Fuzzily

A fast, [trigram](http://en.wikipedia.org/wiki/N-gram)-based, database-backed [fuzzy](http://en.wikipedia.org/wiki/Approximate_string_matching) string search/match engine for Rails.

Loosely inspired from an [old blog post](http://unirec.blogspot.co.uk/2007/12/live-fuzzy-search-using-n-grams-in.html).

Compatible with ActiveRecord 2.3, 3.0, 3.1, 3.2.

## Installation

Add this line to your application's Gemfile:

    gem 'fuzzily'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fuzzily

## Usage

You'll need to setup 2 things:

- a trigram model (your search index) and its migration
- the model you want to search for

Create and ActiveRecord model in your app (this will be used to store a "fuzzy index" of all the models and fields you will be indexing):

    class Trigram < ActiveRecord::Base
      include Fuzzily::Model
    end

Create a migration for it:

    class AddTrigramsModel < ActiveRecord::Migration
      extend Fuzzily::Migration
    end

Instrument your model (your searchable fields do not have to be stored, they can be dynamic methods too):

    class MyStuff < ActiveRecord::Base
      # assuming my_stuffs has a 'name' attribute
      fuzzily_searchable :name, {:scope_field => field_name, :scope_negate => [true/false], :scope_list => []}
    end

For example:

    fuzzily_searchable :name_en, {:scope_field => 'feature_code', :scope_negate => true, :scope_list => ['ADM1', 'ADM2', 'ADM3', 'ADM4', 'ADMD', 'ISL', 'PPLX']}

Will produce:

    { :conditions => ["#{options[:scope_field]} #{(options.has_key?(:scope_negate) && options[:scope_negate]) ? 'NOT' : ''} IN (?)",options[:scope_list]] }
    => WHERE `feature_code` NOT IN ('ADM1', 'ADM2', 'ADM3', 'ADM4', 'ADMD', 'ISL', 'PPLX')

Index your model (will happen automatically for new/updated records):

    MyStuff.bulk_update_fuzzy_name

Search!

    MyStuff.find_by_fuzzy_name('Some Name', :limit => 10)
    # => records



## Indexing more than one field

Just list all the field you want to index, or call `fuzzily_searchable` more than once: 

    class MyStuff < ActiveRecord::Base
      fuzzily_searchable :name_fr, :name_en
      fuzzily_searchable :name_de
    end


## Custom name for the index model

If you want or need to name your index model differently (e.g. because you already have a class called `Trigram`):

    class CustomTrigram < ActiveRecord::Base
      include Fuzzily::Model
    end

    class AddTrigramsModel < ActiveRecord::Migration
      extend Fuzzily::Migration
      trigrams_table_name = :custom_trigrams
    end

    class MyStuff < ActiveRecord::Base
      fuzzily_searchable :name, :class_name => 'CustomTrigram'
    end


## License

MIT licence. Quite permissive if you ask me.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
