require 'open_food_network/order_cycle_form_applicator'

module OpenFoodNetwork
  describe OrderCycleFormApplicator do
    context "unit specs" do
      it "creates new exchanges for incoming_exchanges" do
        coordinator_id = 123
        supplier_id = 456

        incoming_exchange = {:enterprise_id => supplier_id, :incoming => true, :variants => {'1' => true, '2' => false, '3' => true}, :enterprise_fee_ids => [1, 2]}

        oc = double(:order_cycle, :coordinator_id => coordinator_id, :exchanges => [], :incoming_exchanges => [incoming_exchange], :outgoing_exchanges => [])

        applicator = OrderCycleFormApplicator.new(oc)

        applicator.should_receive(:exchange_variant_ids).with(incoming_exchange).and_return([1, 3])
        applicator.should_receive(:exchange_exists?).with(supplier_id, coordinator_id, true).and_return(false)
        applicator.should_receive(:add_exchange).with(supplier_id, coordinator_id, true, {:variant_ids => [1, 3], :enterprise_fee_ids => [1, 2]})
        applicator.should_receive(:destroy_untouched_exchanges)

        applicator.go!
      end

      it "creates new exchanges for outgoing_exchanges" do
        coordinator_id = 123
        distributor_id = 456

        outgoing_exchange = {:enterprise_id => distributor_id, :incoming => false, :variants => {'1' => true, '2' => false, '3' => true}, :enterprise_fee_ids => [1, 2], :pickup_time => 'pickup time', :pickup_instructions => 'pickup instructions'}

        oc = double(:order_cycle, :coordinator_id => coordinator_id, :exchanges => [], :incoming_exchanges => [], :outgoing_exchanges => [outgoing_exchange])

        applicator = OrderCycleFormApplicator.new(oc)

        applicator.should_receive(:exchange_variant_ids).with(outgoing_exchange).and_return([1, 3])
        applicator.should_receive(:exchange_exists?).with(coordinator_id, distributor_id, false).and_return(false)
        applicator.should_receive(:add_exchange).with(coordinator_id, distributor_id, false, {:variant_ids => [1, 3], :enterprise_fee_ids => [1, 2], :pickup_time => 'pickup time', :pickup_instructions => 'pickup instructions'})
        applicator.should_receive(:destroy_untouched_exchanges)

        applicator.go!
      end

      it "updates existing exchanges for incoming_exchanges" do
        coordinator_id = 123
        supplier_id = 456

        incoming_exchange = {:enterprise_id => supplier_id, :incoming => true, :variants => {'1' => true, '2' => false, '3' => true}, :enterprise_fee_ids => [1, 2]}

        oc = double(:order_cycle,
                    :coordinator_id => coordinator_id,
                    :exchanges => [double(:exchange, :sender_id => supplier_id, :receiver_id => coordinator_id, :incoming => true)],
                    :incoming_exchanges => [incoming_exchange],
                    :outgoing_exchanges => [])

        applicator = OrderCycleFormApplicator.new(oc)

        applicator.should_receive(:exchange_variant_ids).with(incoming_exchange).and_return([1, 3])
        applicator.should_receive(:exchange_exists?).with(supplier_id, coordinator_id, true).and_return(true)
        applicator.should_receive(:update_exchange).with(supplier_id, coordinator_id, true, {:variant_ids => [1, 3], :enterprise_fee_ids => [1, 2]})
        applicator.should_receive(:destroy_untouched_exchanges)

        applicator.go!
      end

      it "updates existing exchanges for outgoing_exchanges" do
        coordinator_id = 123
        distributor_id = 456

        outgoing_exchange = {:enterprise_id => distributor_id, :incoming => false, :variants => {'1' => true, '2' => false, '3' => true}, :enterprise_fee_ids => [1, 2], :pickup_time => 'pickup time', :pickup_instructions => 'pickup instructions'}

        oc = double(:order_cycle,
                    :coordinator_id => coordinator_id,
                    :exchanges => [double(:exchange, :sender_id => coordinator_id, :receiver_id => distributor_id, :incoming => false)],
                    :incoming_exchanges => [],
                    :outgoing_exchanges => [outgoing_exchange])

        applicator = OrderCycleFormApplicator.new(oc)

        applicator.should_receive(:exchange_variant_ids).with(outgoing_exchange).and_return([1, 3])
        applicator.should_receive(:exchange_exists?).with(coordinator_id, distributor_id, false).and_return(true)
        applicator.should_receive(:update_exchange).with(coordinator_id, distributor_id, false, {:variant_ids => [1, 3], :enterprise_fee_ids => [1, 2], :pickup_time => 'pickup time', :pickup_instructions => 'pickup instructions'})
        applicator.should_receive(:destroy_untouched_exchanges)

        applicator.go!
      end

      describe "removing exchanges that are no longer present" do
        it "destroys untouched exchanges" do
          coordinator_id = 123
          supplier_id = 456
          exchange = double(:exchange, :id => 1, :sender_id => supplier_id, :receiver_id => coordinator_id, :incoming => true)

          oc = double(:order_cycle,
                      :coordinator_id => coordinator_id,
                      :exchanges => [exchange],
                      :incoming_exchanges => [],
                      :outgoing_exchanges => [])

          applicator = OrderCycleFormApplicator.new(oc)

          applicator.should_receive(:destroy_untouched_exchanges)

          applicator.go!
          applicator.send(:untouched_exchanges).should == [exchange]
        end

        it "compares exchanges by id only" do
          e1 = double(:exchange1, id: 1, foo: 1)
          e2 = double(:exchange2, id: 1, foo: 2)
          oc = double(:order_cycle, :exchanges => [e1])

          applicator = OrderCycleFormApplicator.new(oc)
          applicator.instance_eval do
            @touched_exchanges = [e2]
          end

          applicator.send(:untouched_exchanges).should == []
        end
      end

      it "converts exchange variant ids hash to an array of ids" do
        applicator = OrderCycleFormApplicator.new(nil)

        applicator.send(:exchange_variant_ids, {:enterprise_id => 123, :variants => {'1' => true, '2' => false, '3' => true}}).should == [1, 3]
      end
    end

    context "integration specs" do
      before(:all) do
        require 'spec_helper'
      end

      it "checks whether exchanges exist" do
        oc = FactoryGirl.create(:simple_order_cycle)
        exchange = FactoryGirl.create(:exchange, order_cycle: oc)
        applicator = OrderCycleFormApplicator.new(oc)

        applicator.send(:exchange_exists?, exchange.sender_id, exchange.receiver_id, exchange.incoming).should be_true
        applicator.send(:exchange_exists?, exchange.sender_id, exchange.receiver_id, !exchange.incoming).should be_false
        applicator.send(:exchange_exists?, exchange.receiver_id, exchange.sender_id, exchange.incoming).should be_false
        applicator.send(:exchange_exists?, exchange.sender_id, 999999, exchange.incoming).should be_false
        applicator.send(:exchange_exists?, 999999, exchange.receiver_id, exchange.incoming).should be_false
        applicator.send(:exchange_exists?, 999999, 888888, exchange.incoming).should be_false
      end

      it "adds exchanges" do
        oc = FactoryGirl.create(:simple_order_cycle)
        applicator = OrderCycleFormApplicator.new(oc)
        sender = FactoryGirl.create(:enterprise)
        receiver = FactoryGirl.create(:enterprise)
        incoming = true
        variant1 = FactoryGirl.create(:variant)
        variant2 = FactoryGirl.create(:variant)
        enterprise_fee1 = FactoryGirl.create(:enterprise_fee)
        enterprise_fee2 = FactoryGirl.create(:enterprise_fee)

        applicator.send(:touched_exchanges=, [])
        applicator.send(:add_exchange, sender.id, receiver.id, incoming, {:variant_ids => [variant1.id, variant2.id], :enterprise_fee_ids => [enterprise_fee1.id, enterprise_fee2.id]})

        exchange = Exchange.last
        exchange.sender.should == sender
        exchange.receiver.should == receiver
        exchange.incoming.should == incoming
        exchange.variants.sort.should == [variant1, variant2].sort
        exchange.enterprise_fees.sort.should == [enterprise_fee1, enterprise_fee2].sort

        applicator.send(:touched_exchanges).should == [exchange]
      end

      it "updates exchanges" do
        oc = FactoryGirl.create(:simple_order_cycle)
        applicator = OrderCycleFormApplicator.new(oc)
        sender = FactoryGirl.create(:enterprise)
        receiver = FactoryGirl.create(:enterprise)
        incoming = true
        variant1 = FactoryGirl.create(:variant)
        variant2 = FactoryGirl.create(:variant)
        variant3 = FactoryGirl.create(:variant)
        enterprise_fee1 = FactoryGirl.create(:enterprise_fee)
        enterprise_fee2 = FactoryGirl.create(:enterprise_fee)
        enterprise_fee3 = FactoryGirl.create(:enterprise_fee)

        exchange = FactoryGirl.create(:exchange, order_cycle: oc, sender: sender, receiver: receiver, incoming: incoming, variant_ids: [variant1.id, variant2.id], enterprise_fee_ids: [enterprise_fee1.id, enterprise_fee2.id])

        applicator.send(:touched_exchanges=, [])
        applicator.send(:update_exchange, sender.id, receiver.id, incoming, {:variant_ids => [variant1.id, variant3.id], :enterprise_fee_ids => [enterprise_fee2.id, enterprise_fee3.id]})

        exchange.reload
        exchange.variants.sort.should == [variant1, variant3].sort
        exchange.enterprise_fees.sort.should == [enterprise_fee2, enterprise_fee3]
        applicator.send(:touched_exchanges).should == [exchange]
      end
    end
  end
end
