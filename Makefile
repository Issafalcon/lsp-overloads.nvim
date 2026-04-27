# we disable the `all` command because some external tool might run it automatically
.SUFFIXES:

all:

SPEC_DIR     = spec/lsp_overloads
INIT_FILE    = spec/minimal_init.lua

.PHONY: all test deps test-ci documentation documentation-ci lint check-lint

# runs all the test files using plenary busted runner.
test: deps
	nvim --version | head -n 1 && echo ''
	nvim --headless --clean --noplugin -u $(INIT_FILE) \
		-c "lua vim.cmd([[PlenaryBustedDirectory $(SPEC_DIR) { minimal_init = '$(INIT_FILE)' }]])"

# installs test dependencies into deps/ (always re-checks, skips if already cloned).
deps:
	@mkdir -p deps
	@[ -d deps/plenary ] || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary
	@[ -d deps/mini.doc.nvim ] || git clone --depth 1 https://github.com/echasnovski/mini.doc.git deps/mini.doc.nvim

# installs deps before running tests, useful for the CI.
test-ci: deps test

# generates the documentation.
documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init.lua \
		-c "lua require('mini.doc').setup()" \
		-c "lua require('mini.doc').generate()" \
		-c "qa!"

# installs deps before running the documentation generation, useful for the CI.
documentation-ci: deps documentation

# performs a lint check and fixes issues if possible, following the config in `stylua.toml`.
lint:
	stylua lua plugin spec

# performs a lint check without applying changes (for CI).
check-lint:
	stylua --check lua plugin spec
