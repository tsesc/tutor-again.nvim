.PHONY: test test-unit test-integration dev

test:
	nvim --headless -u scripts/minimal_init.lua \
		-c "lua MiniTest.run()" \
		-c "qall!" 2>&1

test-unit:
	nvim --headless -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_search.lua')" \
		-c "lua MiniTest.run_file('tests/test_history.lua')" \
		-c "qall!" 2>&1

test-integration:
	nvim --headless -u scripts/minimal_init.lua \
		-c "lua MiniTest.run_file('tests/test_integration.lua')" \
		-c "qall!" 2>&1

dev:
	nvim -u NONE -c "lua vim.opt.rtp:prepend('$(CURDIR)'); require('tutor-again').setup({})"
