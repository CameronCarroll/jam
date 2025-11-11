require "./llamaclient"
require "./workspace"
require "./lm_command_processor"
require "./lm_ui"
require "./lm_planner"
require "./lm_prompts"
require "./lm_flow"

# Core module for LLM-based interactions
module LMRoutines
  # Default model to use for queries
  DEFAULT_MODEL = "gpt-oss:20b"

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
