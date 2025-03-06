require "./llamaclient"
require "./workspace"
require "./lm_command_processor"
require "./lm_ui"
require "./lm_planner"

# Core module for LLM-based interactions 
module LMRoutines
  # Constants for system prompts
#   SKELETON_WORKSPACE = "%%%SKELETON_WORKSPACE START%%%
# This is your internal workspace. Use it for memory, cognition, and execution planning.

# %%%SKELETON_WORKSPACE END%%%"
SKELETON_WORKSPACE = ""

  MODEL_GROUNDING = "You are operating within a structured workspace. You have tools available to you."

  WORK_PROMPT = "%%%MY RESPONSE%%%
    [This is where your direct response to the user should be placed. Write your answer here.]"

  REFLECTION_PROMPT = "%%%REFLECTION PROMPT START%%%[In this section, reflect on the recent interaction. Update your SKELETON_WORKSPACE based on the interaction. Do NOT write your user-facing response here.  Use the sections within SKELETON_WORKSPACE to organize your reflections.]%%%REFLECTION PROMPT END%%%"

  # Default model to use for queries
  DEFAULT_MODEL = "command-r7b:latest"

  # Custom errors for routine functions
  class InputError < Exception; end
  class ModelError < Exception; end

  # Helper to build context for model queries
  def self.build_model_context(workspace : Workspace, parts : Hash(Symbol, String)) : String
    context = String.new

    # Always include workspace and grounding
    context += workspace.system_prompt + "\n" if parts.has_key?(:include_workspace)
    context += MODEL_GROUNDING if parts.has_key?(:include_grounding)

    # Add optional components
    context += "\n#{LMCommandProcessor::COMMAND_INSTRUCTIONS}\n" if parts.has_key?(:include_commands)

    # Add any specific parts provided
    parts.each do |key, value|
      next if [:include_workspace, :include_grounding, :include_commands].includes?(key)
      context += value
    end

    context
  end

  # # Helper to handle model requests and responses
  # def self.send_model_request(context : String, model : String, label : String) : String
  #   response = LlamaClient.send_text(context, model)

  #   if response.is_a?(String)
  #     LMUI.print_separator
  #     puts "#{LMUI::BOLD}#{LMUI::CYAN}#{label}:#{LMUI::RESET}"
  #     puts "#{LMUI::GREEN}#{response}#{LMUI::RESET}"
  #     return response
  #   else
  #     raise ModelError.new("Problem with response from the model.")
  #   end
  # end

  # Runs a human-in-loop planning session with the LLM
  # Delegates to specialized components
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL, enable_command_tracking : Bool = false)
    LMPlanner.run_planning_session(workspace, model, enable_command_tracking)
  end

  # Runs a simple chat loop with the LLM
  def self.run_chat_loop(model : String = DEFAULT_MODEL)
    context = String.new
    loop do
      puts "=> "
      input = gets
      if input.is_a?(String)
        case input
        when ""
          next
        when "exit"
          break
        else
          context += input
          model_response = LlamaClient.send_text(context, model)
        end
        if model_response.is_a?(String)
          puts model_response
          context += model_response
        else
          puts "Model error"
        end
      else
        puts "Input error"
      end
    end
  end
end