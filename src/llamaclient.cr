require "http/client"
require "json"

# Module for interacting with an ollama server.
module LlamaClient

    # Sends a text prompt to the Llama 2 API and returns the generated text.
    #
    # Parameters:
    # - `prompt`: The text prompt to send to the API.
    # - `model`: The name of the Llama 2 model to use (e.g., "llama2").
    # - `api_url`: (Optional) The URL of the Llama 2 API. Defaults to "http://localhost:11434/api/generate".
    #
    # Returns:
    # The generated text from the API, or `nil` if an error occurs.
    #
    # Example:
    # ```crystal
    # generated_text = LlamaClient.send_text("Write a short story.", "llama2")
    # if generated_text
    #   puts generated_text
    # end
    # ```
    def self.send_text(prompt : String, model : String, api_url : String = "http://localhost:11434/api/generate")
        headers = HTTP::Headers{
            "Content-Type" => "application/json",
        }

        body = {
            model: model,
            prompt: prompt,
            stream: false,
        }.to_json

        response = HTTP::Client.post(api_url, headers: headers, body: body)

        if response.status.success?
            response_data = JSON.parse(response.body)
            generated_text = response_data["response"].as_s
            return generated_text
        else
            puts "Error #{response.status_code}: #{response.body}"
            return nil
        end

    rescue ex : IO::Error
        puts "Network error: #{ex.message}"
        return nil
    end
end