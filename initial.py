import os
from dotenv import load_dotenv
from agno.agent import Agent
from agno.models.openai import OpenAIChat
from agno.tools.github import GithubTools
from agno.tools.duckduckgo import DuckDuckGoTools
import platform

# Load environment variables
load_dotenv()

# Model configuration
MODEL_CONFIG = {
    "id": os.getenv("LLM_MODEL_ID", "gpt-4o"),          # Default to gpt-4o if not specified
    "api_key": os.getenv("OPENAI_API_KEY"),             # Your OpenAI API key
    "base_url": os.getenv("LLM_API_BASE_URL"),          # Custom API base URL for self-hosted models
    "temperature": float(os.getenv("LLM_TEMPERATURE", "0.7"))
}

# Initialize the agent with GitHub and web search tools
analyzer = Agent(
    model=OpenAIChat(
        id=MODEL_CONFIG["id"],
        api_key=MODEL_CONFIG["api_key"],
        base_url=MODEL_CONFIG["base_url"],
        temperature=MODEL_CONFIG["temperature"]
    ),
    tools=[GithubTools(), DuckDuckGoTools()],
    instructions=[
        "You are a GitHub Open-Source Project Analyzer focused on Python repositories.",
        "Provide explanations tailored to the user's expertise (beginner or senior).",
        "Analyze the repo's codebase, focusing on key Python files (e.g., main.py, requirements.txt).",
        "Search online for tutorials, use cases, or community feedback about the repo.",
        "Evaluate best practices (README, license, tests) and provide a score out of 10.",
        "Generate an OS-specific setup guide for cloning and running the project.",
        "If automation is requested, include a script to clone and set up the project.",
        "Use markdown with tables for repo details and code blocks for setup steps."
    ],
    markdown=True,
    show_tool_calls=True
)

# Function to analyze a Python repository
def analyze_repo(repo_url, expertise="beginner", automate_setup=False):
    # Detect user OS
    user_os = platform.system().lower()
    os_note = "Linux/macOS" if user_os in ["linux", "darwin"] else "Windows"

    prompt = f"""
    Analyze the Python GitHub repository at {repo_url}.
    - **Codebase Explanation**: Summarize the repo's purpose and functionality for a {expertise} developer. For beginners, use analogies; for seniors, detail architecture and patterns.
    - **Online Research**: Search for tutorials, use cases, or community feedback about the repo. Summarize in a 'Community Insights' section.
    - **Best Practices**: Check for README, license, and test files. Provide a score (0-10) and suggestions in a table.
    - **Setup Guide**: Provide a step-by-step guide to clone and run the project on {os_note}. If automate_setup is True, include a shell script for automation.
    - Format output in markdown with tables for repo details and code blocks for setup.
    """
    response = analyzer.print_response(prompt, stream=True)
    return response

# Example usage
if __name__ == "__main__":
    # Test with a popular Python repo (e.g., Flask)
    repo_url = "https://github.com/pallets/flask"
    analyze_repo(repo_url, expertise="beginner", automate_setup=False)