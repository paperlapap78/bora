require "helper/spec_helper"

describe BoraCli do
  let(:bora) { described_class.new }
  before { @stack = setup_stack("web-prod", status: :not_created) }

  it "generates the template using cfndsl if the template is a .rb file" do
    expect(@stack).to receive(:create)
      .with({
        template_body: '{"AWSTemplateFormatVersion":"2010-09-09","Resources":{"EBApp":{"Properties":{"ApplicationName":"MyApp"},"Type":"AWS::ElasticBeanstalk::Application"}}}'
      })
      .and_return(true)

    output = bora.run(bora_config, "apply", "web-prod")
  end

  it "generates pretty json if specified" do
    expect(@stack).to receive(:create)
      .with({
        template_body: JSON.pretty_generate(JSON.parse('{"AWSTemplateFormatVersion":"2010-09-09","Resources":{"EBApp":{"Properties":{"ApplicationName":"MyApp"},"Type":"AWS::ElasticBeanstalk::Application"}}}'))
      })
      .and_return(true)

    output = bora.run(bora_config, "apply", "web-prod", "--pretty")
  end

  def bora_config
    {
      "templates" => {
        "web" => {
          "template_file" => File.join(__dir__, "fixtures/cfndsl_spec_template.rb"),
          "stacks" => {
            "prod" => {}
          }
        }
      }
    }
  end
end
