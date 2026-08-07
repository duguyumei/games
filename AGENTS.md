# Project Agent Instructions

## Godot process safety on macOS

- Never run this project's Godot executable without an explicit `--log-file` path under `/tmp`.
- Use a distinct log file for every invocation, for example:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/taiwu-<test-name>.log --path combo_duel_vslice --script res://tests/<test-name>.gd`
- Run Godot tests serially by default. If parallel execution is necessary, every process must use a different log file.
- Do not write Godot logs to the default `user://logs` directory from Codex. In the managed macOS workspace, failure to rotate that log can crash Godot 4.7.1 with `SIGSEGV` and trigger a macOS crash dialog.
- Godot may return exit code 0 when a requested script cannot be loaded. Treat `ERROR: Can't load script` and `File not found` in stdout as test failures even when the exit code is 0.
- The macOS `get_system_ca_certificates` warning is currently non-blocking for local tests.

