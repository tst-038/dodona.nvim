describe("dodona download queue", function()
	it("never exceeds configured concurrency", function()
		require("dodona.config").setup({ download_concurrency = 2, notify = false })
		package.loaded["dodona.download_queue"] = nil
		local queue = require("dodona.download_queue")
		local active, peak, completed = 0, 0, 0
		local finishers = {}

		for _ = 1, 5 do
			queue.enqueue(function(done)
				active = active + 1
				peak = math.max(peak, active)
				table.insert(finishers, function()
					active = active - 1
					completed = completed + 1
					done()
				end)
				return { shutdown = function() end }
			end)
		end

		assert.equals(2, queue.stats().running)
		assert.equals(3, queue.stats().waiting)
		while completed < 5 do
			local finish = table.remove(finishers, 1)
			assert.is_not_nil(finish)
			finish()
			vim.wait(100, function()
				return #finishers > 0 or completed == 5
			end)
		end
		assert.equals(2, peak)
		assert.equals(0, queue.stats().running)
	end)
end)
