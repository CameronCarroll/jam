require "http/client"
require "json"
module LlamaClient
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