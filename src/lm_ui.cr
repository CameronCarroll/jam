# Module for UI-related functionality and output formatting
module LMUI
  # Define ANSI color codes for terminal output
  CYAN      = "\033[36m"
  GREEN     = "\033[32m"
  YELLOW    = "\033[33m"
  BLUE      = "\033[34m"
  MAGENTA   = "\033[35m"
  RED       = "\033[31m"
  GRAY      = "\033[90m"
  BOLD      = "\033[1m"
  UNDERLINE = "\033[4m"
  RESET     = "\033[0m"

  # Helper to draw a separator line in output
  def self.print_separator
    puts "\n\n\n\n#{GRAY}#{"-" * 50}#{RESET}"
  end

  # Returns ASCII art dividers for file output
  # Cycles through multiple divider styles
  def self.get_ascii_divider(divider_type : Symbol = :random) : String
    dividers = {
      cat: "=^..^=   =^..^=   =^..^=   =^..^=   =^..^=   =^..^=   =^..^=",
      stars: "★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★",
      hearts: "♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥•*¨*•.¸¸♥",
      flowers: "✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀✿❀",
      bubbles: "°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°°o○●○o°"}

    if divider_type == :random
      # Pick a random divider
      divider_keys = dividers.keys
      random_key = divider_keys.sample
      return dividers[random_key]
    elsif dividers.has_key?(divider_type)
      return dividers[divider_type]
    else
      # Default to stars if invalid type provided
      return dividers[:stars]
    end
  end
  
  # Send request to model and write response to output file (along with some pretty ASCII dividers)
  #
  # Returns a String with the model response.
  def self.send_model_request(
    context : String, 
    model : String, 
    label : String, 
    output_file : String,
    temperature : Float64 = 0.6,
    top_p : Float64 = 0.7,
    max_tokens : Int32 = 700) : String
    response = LlamaClient.send_text(context, model)

    if response.is_a?(String)
      # Write to file instead of printing to terminal
      File.open(output_file, "a") do |file|
        # Add a cute ASCII divider
        file.puts get_ascii_divider()
        file.puts "#{label}:"
        file.puts "-" * 80
        file.puts response
      end

      # Just print a short notification to the terminal
      puts "#{CYAN}Received model response (see #{output_file})#{RESET}"

      return response
    else
      raise LMRoutines::ModelError.new("Problem with response from the model.")
    end
  end

  # Write string thing with string label to output file for logging
  #
  # Returns nil
  def self.log_thing(
    thing : String,
    label : String,
    output_file : String)
    File.open(output_file, "a") do |file|
      file.puts get_ascii_divider()
      file.puts("#{label}")
      file.puts "-" * 80
      file.puts thing
    end
  end
end