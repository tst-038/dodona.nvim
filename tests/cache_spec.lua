describe("dodona cache", function()
	local cache

	before_each(function()
		package.loaded["dodona.cache"] = nil
		cache = require("dodona.cache")
		cache.clear()
	end)

	it("expires entries after their TTL", function()
		cache.set("courses:1", { id = 1 }, 10)
		assert.equals(1, cache.get("courses:1").id)
		vim.wait(30)
		assert.is_nil(cache.get("courses:1"))
	end)

	it("deduplicates concurrent loads", function()
		local loads, done = 0, nil
		local results = {}
		local function loader(callback)
			loads = loads + 1
			done = callback
		end
		cache.fetch("series:1", loader, function(_, value)
			table.insert(results, value)
		end)
		cache.fetch("series:1", loader, function(_, value)
			table.insert(results, value)
		end)
		assert.equals(1, loads)
		done(nil, { id = 42 })
		assert.equals(2, #results)
		assert.equals(42, results[1].id)
	end)
end)
