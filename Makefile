# Define all abstract commands here
.PHONY: test init lint

# Lint
lint:
	uvx ruff check --fix --target-version py311 && uvx ruff format --target-version py311

# Run tests
test:
	uv run pytest tests/ -v

# Initialise pre-commit
init:
	@echo "Installing pre-commit..."
	uv add --group dev pre-commit
	@echo "Configuring git hook stages..."
	uv run pre-commit install --hook-type pre-commit
	uv run pre-commit install --hook-type pre-push
	@echo "✓ Setup complete! Hooks will run on commit and push."
