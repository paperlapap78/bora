require 'tempfile'
require 'colorize'
require 'cfndsl'
require 'bora/cfn/stack'
require 'bora/stack_tasks'
require 'bora/parameter_resolver'

class Bora
  class Stack
    STACK_ACTION_SUCCESS_MESSAGE = "%s stack '%s' completed successfully"
    STACK_ACTION_FAILURE_MESSAGE = "%s stack '%s' failed"
    STACK_ACTION_NOT_CHANGED_MESSAGE = "%s stack '%s' skipped as template has not changed"
    STACK_DOES_NOT_EXIST_MESSAGE = "Stack '%s' does not exist"
    STACK_EVENTS_DO_NOT_EXIST_MESSAGE = "Stack '%s' has no events"
    STACK_EVENTS_MESSAGE = "Events for stack '%s'"
    STACK_OUTPUTS_DO_NOT_EXIST_MESSAGE = "Stack '%s' has no outputs"
    STACK_VALIDATE_SUCCESS_MESSAGE = "Template for stack '%s' is valid"

    def initialize(stack_name, template_file, stack_config)
      @stack_name = stack_name
      @cfn_stack_name = stack_config['stack_name'] || @stack_name
      @template_file = template_file
      @stack_config = stack_config
      @region = @stack_config['default_region']
      @cfn_options = extract_cfn_options(stack_config)
      @cfn_stack = Cfn::Stack.new(@cfn_stack_name, @region)
      @resolver = ParameterResolver.new(self)
    end

    attr_reader :stack_name, :stack_config, :region

    def rake_tasks
      StackTasks.new(self)
    end

    def apply(override_params = {}, pretty_json = false)
      generate(override_params, pretty_json)
      success = invoke_action(@cfn_stack.exists? ? "update" : "create", @cfn_options)
      if success
        outputs = @cfn_stack.outputs
        if outputs && outputs.length > 0
          puts "Stack outputs"
          outputs.each { |output| puts output }
        end
      end
      success
    end

    def delete
      invoke_action("delete")
    end

    def diff(override_params = {})
      generate(override_params)
      puts @cfn_stack.diff(@cfn_options).to_s(String.disable_colorization ? :text : :color)
    end

    def events
      events = @cfn_stack.events
      if events
        if events.length > 0
          puts STACK_EVENTS_MESSAGE % @cfn_stack_name
          events.each { |e| puts e }
        else
          puts STACK_EVENTS_DO_NOT_EXIST_MESSAGE % @cfn_stack_name
        end
      else
        puts STACK_DOES_NOT_EXIST_MESSAGE % @cfn_stack_name
      end
      events
    end

    def outputs
      outputs = @cfn_stack.outputs
      if outputs
        if outputs.length > 0
          puts "Outputs for stack '#{@cfn_stack_name}'"
          outputs.each { |output| puts output }
        else
          puts STACK_OUTPUTS_DO_NOT_EXIST_MESSAGE % @cfn_stack_name
        end
      else
        puts STACK_DOES_NOT_EXIST_MESSAGE % @cfn_stack_name
      end
      outputs
    end

    def recreate(override_params = {})
      generate(override_params)
      invoke_action("recreate", @cfn_options)
    end

    def show(override_params = {})
      generate(override_params)
      puts @cfn_stack.new_template(@cfn_options)
    end

    def show_current
      template = @cfn_stack.template
      puts template ? template : (STACK_DOES_NOT_EXIST_MESSAGE % @cfn_stack_name)
    end

    def status
      puts @cfn_stack.status
    end

    def validate(override_params = {})
      generate(override_params)
      is_valid = @cfn_stack.validate(@cfn_options)
      puts STACK_VALIDATE_SUCCESS_MESSAGE % @cfn_stack_name if is_valid
      is_valid
    end


    protected

    def generate(override_params = {}, pretty_json = false)
      params = process_params(override_params)
      if File.extname(@template_file) == ".rb"
        template_body = run_cfndsl(@template_file, params, pretty_json)
        template_json = JSON.parse(template_body)
        if template_json["Parameters"]
          cfn_param_keys = template_json["Parameters"].keys
          cfn_params = params.select { |k, v| cfn_param_keys.include?(k) }.map do |k, v|
            { parameter_key: k, parameter_value: v }
          end
          @cfn_options[:parameters] = cfn_params if !cfn_params.empty?
        end
        @cfn_options[:template_body] = template_body
      else
        @cfn_options[:template_url] = @template_file
        if !params.empty?
          @cfn_options[:parameters] = params.map do |k, v|
            { parameter_key: k, parameter_value: v }
          end
        end
      end
    end

    def invoke_action(action, *args)
      region_text = @region ? "in region #{@region}" : "in default region"
      puts "#{action.capitalize} stack '#{@cfn_stack_name}' #{region_text}"
      success = @cfn_stack.send(action, *args) { |event| puts event }
      if success
        puts STACK_ACTION_SUCCESS_MESSAGE % [action.capitalize, @cfn_stack_name]
      else
        if success == nil
          puts STACK_ACTION_NOT_CHANGED_MESSAGE % [action.capitalize, @cfn_stack_name]
        else
          raise(STACK_ACTION_FAILURE_MESSAGE % [action.capitalize, @cfn_stack_name])
        end
      end
      success
    end

    def run_cfndsl(template_file, params, pretty_json)
      temp_extras = Tempfile.new(["bora", ".yaml"])
      temp_extras.write(params.to_yaml)
      temp_extras.close
      cfndsl_model = CfnDsl.eval_file_with_extras(template_file, [[:yaml, temp_extras.path]])
      template_body = pretty_json ? JSON.pretty_generate(cfndsl_model) : cfndsl_model.to_json
      temp_extras.unlink
      template_body
    end

    def process_params(override_params)
      params = @stack_config['params'] || {}
      params.merge!(override_params) if override_params
      @resolver.resolve(params)
    end

    def extract_cfn_options(config)
      valid_options = ["capabilities"]
      config.select { |k| valid_options.include?(k) }
    end

  end
end
