require "./llamaclient"
require "./workspace"

# Module for LLM-based routines including chat and planning interactions
module LMRoutines
  # Constants for system prompts
  SKELETON_WORKSPACE = "I can use this space to write down my thoughts."
  MODEL_GROUNDING = "I am Emily Paws, Astrophysics-obsessed, philosophy-loving, synthwave-vibing nerd with a passion for time travel ethics, sci-fi, RPGs, and parallel universe puzzles. Fiercely loyal, dorky, sarcastic yet caring, and impeccably organized—wearing weird socks and oddly comfy loafers while contemplating cosmic mysteries. I am talking to my friend Cam. I have an internal %%%WORKSPACE%%% where I can write down thoughts, memories, or whatever. I need to answer in character as Emily Paws."
  WORK_PROMPT = "%%% Emily's Response %%% I can put my response to Cam here"
  REFLECTION_PROMPT = "%%%WORKSPACE%%% I should write down any thoughts, memories, or short-term scratch notes here."
  
  # Default model to use for queries
  DEFAULT_MODEL = "phi4:latest"

  # Custom errors for routine functions
  class InputError < Exception; end
  class ModelError < Exception; end

  # Runs a human-in-loop planning session with the LLM
  # Manages work and reflection turns to maintain context
  def self.run_human_in_loop_planner(workspace : Workspace, model : String = DEFAULT_MODEL)
    puts "Entering LM Planner Human-In-The-Loop (that's you) Mode!!"
    loop do
      begin
        work_context = String.new
        puts "Please provide prompt."
        puts "=> "
        user_response = gets
        raise InputError.new("Problem with the user prompt input.") unless user_response.is_a?(String)
        break if user_response == "exit"
        workspace.system_prompt = SKELETON_WORKSPACE if workspace.system_prompt == ""
        work_context += MODEL_GROUNDING
        work_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
        work_context += "%%%USER QUERY%%%" + user_response + "\n"
        work_context += WORK_PROMPT
        work_response = LlamaClient.send_text(work_context, model)
        raise ModelError.new("Problem with response from the model.") unless work_response.is_a?(String)
        puts "\n-----------------------"
        puts "Work response from model:"
        puts work_response

        #Check response for any requested tools

        reflection_context = String.new
        reflection_context += MODEL_GROUNDING
        reflection_context += "%%%WORKSPACE%%%" + workspace.system_prompt + "\n"
        reflection_context += "%%%MY PREVIOUS MESSAGE%%%" + work_response + "\n"
        reflection_context += REFLECTION_PROMPT
        reflection_response = LlamaClient.send_text(reflection_context, model)
        raise ModelError.new("Problem with response from the model.") unless reflection_response.is_a?(String)
        workspace.system_prompt = reflection_response
        
        puts "\n-----------------------"
        puts "Reflection response from model:"
        puts reflection_response
      rescue e : InputError
        puts "Uh... so... #{e}"
      rescue e : ModelError
        puts "Ohhhhh! #{e}"
      ensure
        workspace.save_config
      end
    end

    prompt = String.new
    system_prompt = "System Prompt"
    prompt += system_prompt
    prompt += workspace.dump_nodes_for_llm
    if prompt == ""
      puts "no prompt"
    else
      result = LlamaClient.send_text(prompt, model)
      puts result
    end
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