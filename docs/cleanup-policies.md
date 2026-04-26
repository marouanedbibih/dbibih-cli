# Cleanup Policies

## Node.js cleanup

- Scans for `node_modules` folders.
- Supports ignore rules and grouped Yarn cache.
- Shows a detailed table before deletion.
- Requires explicit confirmation before delete.

## Docker cleanup

- Aggressive default includes:
  - stopped containers
  - dangling and unused images
  - unused networks
  - unused volumes
  - build cache
- Shows detailed table and summary before deletion.
- Requires explicit confirmation before delete.

## Python and system cleanup

- Reserved for future enhancement.
- Current placeholders do not perform destructive cleanup.
