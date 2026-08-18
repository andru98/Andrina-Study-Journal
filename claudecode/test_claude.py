import os
from dotenv import load_dotenv
from anthropic import Client, HUMAN_PROMPT, AI_PROMPT

load_dotenv()
print("Python:", __import__("sys").executable)
print("ANTHROPIC_API_KEY loaded:", bool(os.environ.get("ANTHROPIC_API_KEY")))

client = Client(api_key=os.environ["ANTHROPIC_API_KEY"])
prompt = HUMAN_PROMPT + "Write a short poem about data science.\n" + AI_PROMPT

response = client.create_completion(
    model="claude-3.5",
    max_tokens_to_sample=150,
    prompt=prompt,
)

print(response.completion)
