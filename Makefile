# we disable the `all` command because some external tool might run it automatically
.SUFFIXES:

all:

PLENARY_PATH ?= /home/adam/.local/share/nvim/site/pack/core/opt/plenary.nvim
SPEC_DIR     = spec/lsp_overloads
INIT_FILE    = spec/minimal_init.lua

# runs all the test files using plenary busted runner.
test:
	nvim --version | head -n 1 && echo ''
	nvim --headless --clean --noplugin -u $(INIT_FILE) \
		-c "lua vim.cmd([[PlenaryBustedDirectory $(SPEC_DIR) { minimal_init = '$(INIT_FILE)' }]])"

# installs test dependencies.
deps:
	@mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.doc.git deps/mini.doc.nvim 2>/dev/null || true

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
