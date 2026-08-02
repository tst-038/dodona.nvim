describe("dodona async API", function()
	local api

	before_each(function()
		package.loaded["dodona.api"] = nil
		package.loaded["plenary.curl"] = {
			request = function(opts)
				vim.schedule(function()
					opts.callback({ status = 201, exit = 0, body = '{"ok":true}', headers = {} })
				end)
				return { shutdown = function() end }
			end,
		}
		api = require("dodona.api")
		api.setup({ token = "secret", base_url = "https://example.test", request_timeout = 100 })
	end)

	after_each(function()
		package.loaded["plenary.curl"] = nil
	end)

	it("accepts all successful 2xx responses asynchronously", function()
		local completed = false
		api.post_async("/items", { name = "value" }, function(err, response)
			assert.is_nil(err)
			assert.equals(201, response.status)
			assert.is_true(response.body.ok)
			completed = true
		end)
		assert.is_true(vim.wait(500, function()
			return completed
		end))
	end)

	it("reports a missing token without starting a request", function()
		api.setup({ base_url = "https://example.test" })
		local message
		api.get_async("/items", {}, function(err)
			message = err.message
		end)
		assert.is_true(vim.wait(500, function()
			return message ~= nil
		end))
		assert.matches("DodonaSetToken", message)
	end)
end)
