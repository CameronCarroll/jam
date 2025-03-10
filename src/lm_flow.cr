require "./workspace"
require "./lm_command_processor"
require "./lm_ui"
require "./lm_prompts"
require "./llamaclient"

# Represents a generic LLM inference operation
#
# Base class for different LLM-based processing flows.
# Examples include planning steps, command generation, reflection, etc.
class LMFlow
  # Flow configuration
  property model : String
  property temperature : Float64
  property top_p : Float64
  property max_tokens : Int32
  property workspace : Workspace

  # Output configuration
  property output_file : String

  # Flow state
  property input : String
  property output : String
  property context : String

  # Custom errors for flow operations
  class InputError < Exception; end

  class ModelError < Exception; end

  def initialize(
    @workspace : Workspace,
    @model : String,
    @output_file : String,
    @temperature : Float64 = 0.6,
    @top_p : Float64 = 0.7,
    @max_tokens : Int32 = 700,
  )
    @input = ""
    @output = ""
    @context = ""
  end

  # Build context for the model (template method)
  def build_context(input : String) : String
    @input = input
    @context = input
    return @context
  end

  # Execute the flow to get a response from the model
  def execute : String
    @output = LMUI.send_model_request(
      @context,
      @model,
      self.class.name + " response",
      @output_file,
      @temperature,
      @top_p,
      @max_tokens
    )
    return @output
  end

  # Run the flow from start to finish
  def run(input : String) : String
    build_context(input)
    execute
    return process_output
  end

  # Process the output (template method to be overridden by subclasses)
  def process_output : String
    return @output
  end

  # Helper to build context for model queries
  def build_model_context(parts : Hash(Symbol, String)) : String
    context = String.new

    # Always include workspace and grounding
    context += @workspace.system_prompt + "\n" if parts.has_key?(:include_workspace)
    context += LMPrompts::MODEL_GROUNDING if parts.has_key?(:include_grounding)

    # Add any specific parts provided
    parts.each do |key, value|
      next if [:include_workspace, :include_grounding, :include_commands].includes?(key)
      context += value
    end

    # Add commands
    context += "\n#{LMPrompts::COMMAND_INSTRUCTIONS}\n" if parts.has_key?(:include_commands)

    return context
  end

  # Log content to the output file
  def log_thing(thing : String, label : String)
    LMUI.log_thing(thing, label, @output_file)
  end
end

# Planning step flow
class PlannerFlow < LMFlow
  def initialize(
    workspace : Workspace,
    model : String,
    output_file : String,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700,
  )
    super(workspace, model, output_file, temperature, top_p, max_tokens)
  end

  def build_context(user_query : String) : String
    @input = user_query
    # Build initial work context
    @context = build_model_context({
      :include_workspace => "yes",
      :include_grounding => "yes",
    })
    @context += LMPrompts::SHORT_COMMAND_INSTRUCTIONS
    @context += "%%%CURRENT NODES:%%% " + Planner.dump_dependency_graph(@workspace)
    @context += "%%%USER QUERY%%% " + user_query
    @context += LMPrompts::NORTHSTAR_PROMPT + @workspace.modeldata["northstar"]
    @context += LMPrompts::PLAN_PROMPT

    # Log the context
    log_thing(@context, "Plan Context")

    return @context
  end

  def process_output : String
    # Store the plan in the workspace
    @workspace.modeldata["plan"] = @output
    return @output
  end
end

# Command generator flow
class CommandGeneratorFlow < LMFlow
  def initialize(
    workspace : Workspace,
    model : String,
    output_file : String,
    temperature : Float64 = 0.3,
    top_p : Float64 = 0.3,
    max_tokens : Int32 = 700,
  )
    super(workspace, model, output_file, temperature, top_p, max_tokens)
  end

  def build_context(plan : String) : String
    @input = plan

    @context = build_model_context({
      :include_grounding => "yes",
    })
    @context += plan
    @context += "%%%CURRENT NODES:%%% " + @workspace.dump_nodes_for_llm
    @context += LMPrompts::COMMAND_INSTRUCTIONS
    @context += LMPrompts::COMMAND_PROMPT

    # Log the context
    log_thing(@context, "Command Context")

    return @context
  end
end

# Command processor flow
class CommandProcessorFlow < LMFlow
  property command_history : Array(Hash(String, JSON::Any))?
  property followup_output_file : String
  property command_generator : CommandGeneratorFlow

  def initialize(
    workspace : Workspace,
    model : String,
    output_file : String,
    @followup_output_file : String,
    @command_generator : CommandGeneratorFlow,
    @command_history : Array(Hash(String, JSON::Any))? = nil,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700,
  )
    super(workspace, model, output_file, temperature, top_p, max_tokens)
  end

  def process_output : String
    command_response = @output
    final_response = "Attempting to run tools... "
    puts "DEBUG: Inside process_output block of our command processor"
    # Check for any commands in the initial response
    if cmd_result = LMCommandProcessor.process_json_commands(command_response, @workspace, @command_history)
      # Write command execution to file
      File.open(@followup_output_file, "a") do |file|
        # Add a cute ASCII divider
        file.puts LMUI.get_ascii_divider(:bubbles)
        file.puts "EXECUTING COMMAND:"
        file.puts "-" * 80
        file.puts cmd_result
      end

      # Also print a brief notification to terminal
      puts "#{LMUI::MAGENTA}Executing command (see #{@followup_output_file})#{LMUI::RESET}"

      # Build context for command follow-up
      followup_command_context = build_model_context({
        :include_grounding => "yes",
        :include_commands  => "yes",
        :previous_response => "%%%YOUR COMMAND WAS:%%% #{command_response}\n",
        :command_result    => "%%%RESULT FROM EXECUTING COMMAND%%%\n#{cmd_result}\n",
      })
      followup_command_context += "%%%CURRENT NODES:%%% " + @workspace.dump_nodes_for_llm
      followup_command_context += "%%%ORIGINAL PLAN:%%%" + @workspace.modeldata["plan"]
      followup_command_context += "%%%ORIGINAL USER QUERY:%%%" + @workspace.modeldata["user_query"]
      followup_command_context += "%%%ULTIMATE OBJECTIVE:%%%" + @workspace.modeldata["northstar"]
      followup_command_context += "%%%YOUR FOLLOWUP COMMANDS%%% [This is where you should emit any follow-up commands in the proper JSON format."

      # Get follow-up response after command execution
      follow_up = LMUI.send_model_request(
        followup_command_context,
        @model,
        "Follow-up response from model",
        @followup_output_file
      )

      if follow_up.includes?("<DONE>")
        LMUI.log_thing("Model emitted <DONE> token during command execution", "Command Execution", @followup_output_file)
        return follow_up
      end

      followup_command_response = @command_generator.run(follow_up)
      number_of_followups = 1
      # Process any additional commands in the follow-up response
      while cmd_result = LMCommandProcessor.process_json_commands(followup_command_response, @workspace, @command_history)
        puts "Iteration number: #{number_of_followups}"
        break if number_of_followups > 3
        number_of_followups += 1
        # Write additional command execution to file
        File.open(@followup_output_file, "a") do |file|
          # Add a cute ASCII divider
          file.puts LMUI.get_ascii_divider(:flowers)
          file.puts "EXECUTING ADDITIONAL COMMAND:"
          file.puts "-" * 80
          file.puts cmd_result
        end

        if cmd_result.includes?("<DONE>")
          LMUI.log_thing("Model emitted <DONE> token during command execution", "Command Execution", @followup_output_file)
          break
        end

        # Also print a brief notification to terminal
        puts "#{LMUI::MAGENTA}Executing additional command (see #{@followup_output_file})#{LMUI::RESET}"

        # Build context for additional command follow-up
        command_context = build_model_context({
          :include_grounding => "yes",
          :include_commands  => "yes",
          :previous_response => "%%%YOUR COMMAND WAS:%%% #{command_response}\n",
          :command_result    => "%%%RESULT FROM EXECUTING COMMAND%%%\n#{cmd_result}\n",
        })
        followup_command_context += "%%%CURRENT NODES:%%% " + @workspace.dump_nodes_for_llm
        followup_command_context += "%%%ORIGINAL PLAN:%%%" + @workspace.modeldata["plan"]
        followup_command_context += "%%%ORIGINAL USER QUERY:%%%" + @workspace.modeldata["user_query"]
        followup_command_context += "%%%ULTIMATE OBJECTIVE:%%%" + @workspace.modeldata["northstar"]
        followup_command_context += "%%%YOUR FOLLOWUP COMMANDS%%% [This is where you should emit any follow-up commands in the proper JSON format. Say '<DONE>' if there is nothing else to do.]"

        # Get another follow-up response
        follow_up = LMUI.send_model_request(command_context, @model, "Follow-up response from model", @followup_output_file)
        followup_command_response = @command_generator.run(follow_up)
        final_response = followup_command_response
      end
    else
      final_response += "Unsuccessful tool execution?"
      puts "Did not run any tools. (ELSE case of process_json_commands)"
    end

    return final_response
  end
end

# Reflection flow
class ReflectionFlow < LMFlow
  def initialize(
    workspace : Workspace,
    model : String,
    output_file : String,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700,
  )
    super(workspace, model, output_file, temperature, top_p, max_tokens)
  end

  def build_context(final_response : String) : String
    @input = final_response

    @context = build_model_context({
      :include_workspace => "yes",
      :include_grounding => "yes",
      :previous_message  => "%%%YOUR LAST TOOL EXECUTION RESULT%%%" + final_response + "\n",
    })
    @context += "%%%Original Query from User%%%" + @workspace.modeldata["user_query"]
    @context += "%%%ULTIMATE OBJECTIVE%%%" + @workspace.modeldata["northstar"]
    @context += "%%%Your original plan before running tools:%%%" + @workspace.modeldata["plan"]
    @context += LMPrompts::REFLECTION_PROMPT

    # Log the context
    log_thing(@context, "Reflection Context")

    return @context
  end

  def process_output : String
    reflection_response = @output

    if reflection_response.blank?
      # Panic sequence: revert to last stable prompt + log catastrophe
      @workspace.system_prompt = @workspace.modeldata["last_stable_prompt"] || LMPrompts::REFLECTION_PROMPT
      puts "Reflection nullified! Singularity imminent!"
    else
      # Update workspace with reflection. Since we passed our (currently single) sanity check on reflection result,
      # we'll update the last stable prompt as well.
      @workspace.system_prompt = reflection_response
      @workspace.modeldata["last_stable_prompt"] = reflection_response
    end

    return reflection_response
  end
end
