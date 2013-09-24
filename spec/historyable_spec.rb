require 'spec_helper'

describe Historyable do

  before do
    run_migration do
      create_table(:cats, force: true) do |t|
        t.string :name
        t.string :age
      end

      create_table(:dogs, force: true) do |t|
        t.string :name
        t.string :age
      end
    end
  end

  class Cat < ActiveRecord::Base
    include Historyable

    attr_accessor :age

    has_history :name
  end

  class Dog < ActiveRecord::Base
    include Historyable

    attr_accessor :age

    has_history :name
  end

  let(:cat) { Cat.create }
  let(:dog) { Dog.create }

  describe :InstanceMethods do
    before do
      cat.update_attribute(:name, 'Garfield')
    end

    describe :name_history? do
      it { expect(cat.name_history?).to be_true }
      it { expect(dog.name_history?).to be_false }
    end

    describe :name_history do
      it { expect(cat.name_history).to       be_an_instance_of(Array) }
      it { expect(cat.name_history.first).to be_a_kind_of(Hash) }
      it { expect(cat.name_history.first[:attribute_value]).to eq('Garfield') }
      it { expect(dog.name_history).to       be_an_instance_of(Array) }
      it { expect(dog.name_history).to       be_empty }

      describe :Caching do

        describe "creation" do
          context "with a cold cache" do
            it "hits the database" do
              expect(cat).to receive(:name_history_raw).and_call_original
              cat.name_history
            end
          end

          context "with a warm cache" do
            before { cat.name_history }

            it "doesn't hit the database" do
              expect(cat).not_to receive(:name_history_raw).and_call_original
              cat.name_history
            end
          end
        end

        describe "expiration" do
          before do
            cat.name_history
            cat.update_attribute(:name, 'Amadeus')
          end

          it "hits the database" do
            expect(cat).to receive(:name_history_raw).and_call_original
            cat.name_history
          end
        end
      end
    end

    describe :name_history_raw do
      it { expect(cat.name_history_raw).to       be_a_kind_of(ActiveRecord::Relation) }
      it { expect(cat.name_history_raw.first).to be_an_instance_of(Change) }
      it { expect(cat.name_history_raw.first[:object_attribute_value]).to eq('Garfield') }
    end
  end

  describe :Callbacks do
    describe :save_changes do
      it { expect{ cat.update_attribute(:name, 'Garfield') }.to change { cat.name_history.size }.from(0).to(1) }
      it { expect{ cat.update_attribute(:age, 6) }.to_not       change { cat.name_history.size } }
    end
  end
end
