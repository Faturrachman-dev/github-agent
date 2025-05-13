# GitHub Open-Source Project Analyzer

A powerful AI-powered tool that analyzes Python repositories on GitHub, providing insights, documentation, and setup instructions tailored to different expertise levels.

## Overview

This tool uses AI to analyze GitHub repositories, specifically focusing on Python projects. It provides:

- **Codebase explanations** tailored to different expertise levels (beginner, intermediate, senior)
- **Community insights** by searching for tutorials, use cases, and community feedback
- **Best practices evaluation** with scoring for README quality, license presence, testing, etc.
- **OS-specific setup guides** for running the project locally
- Optional **setup automation scripts**

## Features

- 🧠 **Expertise-based analysis**: Get explanations adapted to your knowledge level
- 🔍 **Deep code insights**: Examines repository structure, key files, and architecture
- 📊 **Best practices evaluation**: Scores repositories against industry standards
- 📚 **Community research**: Gathers external information about project usage and reception
- 🛠️ **Setup assistance**: OS-specific instructions to get projects running locally

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/github-agent.git
   cd github-agent
   ```

2. Create and activate a virtual environment:
   ```bash
   # Windows
   python -m venv .venv
   .venv\Scripts\activate

   # Linux/macOS
   python -m venv .venv
   source .venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Configuration

1. Create a `.env` file in the project root (use `.env.example` as a template):
   ```
   # OpenAI API Key
   OPENAI_API_KEY=your_openai_api_key_here

   # Model configuration
   LLM_MODEL_ID=gpt-4o                        # Model ID (e.g., gpt-4o, llama3, etc.)
   LLM_API_BASE_URL=https://your-api-url.com  # For custom OpenAI-compatible APIs
   LLM_TEMPERATURE=0.7                        # Model temperature (0.0 to 1.0)

   # GitHub API Token (optional, for deeper repository analysis)
   GITHUB_API_TOKEN=your_github_token_here
   ```

2. Get a GitHub API token:
   - Go to GitHub → Settings → Developer settings → Personal access tokens
   - Generate a new "fine-grained token" with the following permissions:
     - Repository access: Select repositories or all repositories
     - Permissions needed: "Contents" (Read-only) and "Metadata" (Read-only)

3. Get an OpenAI API key or configure a compatible alternative LLM

## Usage

### Basic Usage

```python
from initial import analyze_repo

# Analyze a repository with default settings (beginner level, no automation)
analyze_repo("https://github.com/username/repo-name")

# Analyze for a senior developer
analyze_repo("https://github.com/username/repo-name", expertise="senior")

# Analyze with setup automation script
analyze_repo("https://github.com/username/repo-name", automate_setup=True)
```

### Running the Example

```bash
# Analyze Flask for beginners
python initial.py
```

### Expertise Levels

- **beginner**: Uses analogies and high-level explanations
- **intermediate**: More detailed technical information
- **senior**: Focuses on architecture, patterns, and implementation details

## How It Works

The analyzer uses the Agno framework to create an AI agent with:

1. **GithubTools**: For directly analyzing repository structure and content
2. **DuckDuckGoTools**: For gathering external information about the repository
3. **OpenAI Integration**: Powered by GPT models (configurable to other providers)

## Contributing

Contributions are welcome! Please feel free to submit a pull request.

## License

[MIT License](LICENSE)