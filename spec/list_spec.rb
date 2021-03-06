require "helper/spec_helper"

describe BoraCli do
  let(:bora_cli) { described_class.new }

  before do
    @config = {
      "templates" => {
        "web" => {
          "template_file" => "web_template.json",
          "stacks" => {
            "dev" => {},
            "prod" => {}
          }
        },
        "app" => {
          "template_file" => "app_template.json",
          "stacks" => {
            "dev" => {},
            "prod" => {}
          }
        }
      }
    }
  end

  it "lists all available stacks" do
    output = bora_cli.run(@config, "list")
    expect(output).to include("web-dev", "web-prod", "app-dev", "app-prod")
  end

  it "allows you to retrieve a template programmatically" do
    bora = Bora.new(config_file_or_hash: @config)
    expect(bora.template("web")).to_not be(nil)
  end

end
