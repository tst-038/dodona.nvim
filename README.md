# dodona.nvim

A modern Neovim client for [Dodona](https://dodona.be): browse courses and activities, download exercise files and media, submit solutions, and follow evaluation progress without blocking the editor.

## Requirements

- Neovim 0.10+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- `curl`
- Optional: [nvim-notify](https://github.com/rcarriga/nvim-notify) and [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)

## Installation

```lua
{
  "tst-038/dodona.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "rcarriga/nvim-notify",       -- optional
    "nvim-tree/nvim-web-devicons", -- optional
  },
  cmd = {
    "DodonaSubmit",
    "DodonaInit",
    "DodonaInitActivities",
    "DodonaSearch",
    "DodonaDownload",
    "DodonaGo",
    "DodonaSetToken",
    "DodonaCancel",
    "DodonaClearCache",
  },
  opts = {},
}
```

For local development, replace the repository with:

```lua
dir = "/absolute/path/to/dodona.nvim"
```

## Configuration

```lua
require("dodona").setup({
  base_url = "https://dodona.be",
  go_cmd = "open",          -- macOS; use "xdg-open" on Linux
  download_on_init = false,
  request_timeout = 10000,
  poll_interval = 2000,
  poll_timeout = 60000,
  download_concurrency = 4,
  cache_ttl = 30000,       -- milliseconds; courses, series and activities
  notify = true,
  progress = true,
  hooks = {
    on_request = nil,
    on_response = nil,
    on_error = nil,
  },
})
```

Run `:DodonaSetToken` once to enter the API token using a hidden prompt. It is stored below Neovim's data directory in a user-only directory (`0700`) and file (`0600`). A `token` passed directly to `setup()` takes precedence and is never persisted automatically.

Exercise files need a Dodona activity URL on their first line, usually as a language comment:

```text
https://dodona.be/en/courses/123/series/456/activities/789/
```

## Commands

| Command | Description |
| --- | --- |
| `:DodonaSubmit` | Submit the current buffer contents, including unsaved changes, and follow evaluation progress. |
| `:DodonaInit` | Browse subscribed courses and download activities. |
| `:DodonaInitActivities` | Alias for `:DodonaInit`. |
| `:DodonaSearch` | Search courses or activities. |
| `:DodonaDownload` | Download media linked by the current activity. |
| `:DodonaGo` | Open the activity URL from the first line. |
| `:DodonaSetToken` | Securely replace the API token. |
| `:DodonaCancel` | Cancel active Dodona API operations and polling. |
| `:DodonaClearCache` | Invalidate cached courses, series, and activities. |

Use `:checkhealth dodona` to diagnose dependencies and token configuration.
