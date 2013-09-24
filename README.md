# Historyable

A simple and solid concern to track ActiveRecord models attributes changes.

You may want to use [PaperTrail](https://github.com/airblade/paper_trail) or other [ActiveRecord versioning libraries](https://www.ruby-toolbox.com/categories/Active_Record_Versioning) for a more thorough usage.

[![Gem Version](https://badge.fury.io/rb/historyable.png)](https://rubygems.org/gems/historyable)
[![Code Climate](https://codeclimate.com/github/hooktstudios/historyable.png)](https://codeclimate.com/github/hooktstudios/historyable)
[![Coverage Status](https://coveralls.io/repos/hooktstudios/historyable/badge.png)](https://coveralls.io/r/hooktstudios/historyable)
[![Travis](https://travis-ci.org/hooktstudios/historyable.png?branch=master)](https://travis-ci.org/hooktstudios/historyable)

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'historyable'
```

And then execute

```bash
$ bundle install
```

Generate and run the migration to add the `changes` table:

```bash
$ rails generate historyable:install
$ rake db:migrate
```

## Usage
```ruby
# db/migrate/create_users.rb
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :first_name
      t.string :last_name
    end
  end
end
```

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  include Historyable

  has_history :first_name, :last_name
end
```

And now you can:

```ruby
u = User.new
u.first_name = 'Philippe'
u.save

u.first_name_history
# => [
        {
          "attribute_value" => "Philippe",
          "changed_at" => Tue, 20 Aug 2013 16:20:00 UTC +00:00
        }
      ]


u.first_name = 'Jean-Philippe'
u.save
u.first_name_history
# => [
        {
          "attribute_value" => "Jean-Philippe",
          "changed_at" => Tue, 20 Aug 2013 16:20:10 UTC +00:00
        },
        {
          "attribute_value" => "Philippe",
          "changed_at" => Tue, 20 Aug 2013 16:20:00 UTC +00:00
        }
      ]
```

## Known shortcomings

It is not possible to directly query attribute values since model attributes tracked by Historyable are serialized in the database.

To overcome this limitation, Historyable also exposes the raw `ActiveRecord` polymorphic relation.

```ruby
u.first_name_history_raw
# => #<ActiveRecord::Relation [#<Change id: nil, object_attribute_value: "Jean-Philippe", created_at: "2013-08-20 16:20:10">], [#<Change id: nil, object_attribute_value: "Philippe", created_at: "2013-08-20 16:20:00">]>
```

## Contributing

See [CONTRIBUTING.md](https://github.com/hooktstudios/historyable/blob/master/CONTRIBUTING.md) for more details on contributing and running test.

## Credits

![hooktstudios](http://hooktstudios.com/logo.png)

[historyable](https://rubygems.org/gems/historyable) is maintained and funded by [hooktstudios](http://github.com/hooktstudios).
