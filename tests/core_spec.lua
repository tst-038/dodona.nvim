describe("dodona core", function()
	before_each(function()
		package.loaded["dodona.config"] = nil
	end)

	it("merges and normalizes configuration", function()
		local config = require("dodona.config")
		local values = config.setup({ base_url = "https://example.test/", notify = false })
		assert.equals("https://example.test", values.base_url)
		assert.equals(10000, values.request_timeout)
		assert.is_false(values.notify)
	end)

	it("encodes and orders query parameters", function()
		local api = require("dodona.api")
		assert.equals("https://example.test?a=hello%20world&z=2", api.build_url("https://example.test", {
			z = 2,
			a = "hello world",
		}))
	end)

	it("cancels tasks once", function()
		local calls = 0
		local task = require("dodona.task").new(function()
			calls = calls + 1
		end)
		task:cancel()
		task:cancel()
		assert.equals(1, calls)
		assert.is_true(task.cancelled)
	end)

	it("submits unsaved buffer contents", function()
		local submitted
		package.loaded["dodona.manager"] = {
			evalSubmissionContent = function(content, extension)
				submitted = { content = content, extension = extension }
			end,
		}
		package.loaded["dodona"] = nil
		vim.api.nvim_buf_set_name(0, "/private/tmp/dodona-unsaved.py")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# activity URL", "print('unsaved')" })
		require("dodona").submit()
		assert.equals("# activity URL\nprint('unsaved')", submitted.content)
		assert.equals("py", submitted.extension)
		package.loaded["dodona.manager"] = nil
	end)
end)
