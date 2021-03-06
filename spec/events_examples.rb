require 'helper/spec_helper'

shared_examples 'bora#events' do
  describe "#events" do
    context "stack does not exist" do
      before { @stack = setup_stack("web-prod", status: :not_created) }

      it "indicates that the stack does not exist" do
        expect(@stack).to receive(:events).and_return(nil)
        output = bora.run(@config, "events", "web-prod")
        expect(output).to include(Bora::Stack::STACK_DOES_NOT_EXIST_MESSAGE % "web-prod")
      end
    end

    context "stack exists" do
      before { @stack = setup_stack("web-prod", status: :create_complete) }

      it "prints event detail" do
        events = [
          Aws::CloudFormation::Types::StackEvent.new(
            timestamp: Time.new("2016-07-21 15:01:00"),
            logical_resource_id: "1234",
            resource_type: "ApiGateway",
            resource_status: "CREATE_COMPLETE",
            resource_status_reason: "reason1"
          ),
          Aws::CloudFormation::Types::StackEvent.new(
            timestamp: Time.new("2016-07-21 15:00:00"),
            logical_resource_id: "5678",
            resource_type: "LambdaFunction",
            resource_status: "CREATE_FAILED"
          )
        ]

        bora_events = events.map { |e| Bora::Cfn::Event.new(e) }
        expect(@stack).to receive(:events).and_return(bora_events)
        output = bora.run(@config, "events", "web-prod")
        events.map(&:to_a).flatten.each { |v| expect(output).to include(v.to_s) }
      end

      it "indicates there is nothing to show if there are no events" do
        expect(@stack).to receive(:events).and_return([])
        output = bora.run(@config, "events", "web-prod")
        expect(output).to include(Bora::Stack::STACK_EVENTS_DO_NOT_EXIST_MESSAGE % "web-prod")
      end
    end
  end
end
