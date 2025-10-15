# Environment Variable Guide

This guide documents environment variable naming conventions and change procedures for BorgStack to prevent CI/CD issues.

## Critical Naming Conventions

### Database Variables
- **PostgreSQL**: `POSTGRES_PASSWORD`, `{SERVICE}_DB_PASSWORD`
- **MongoDB**: `MONGODB_ROOT_PASSWORD`, `LOWCODER_DB_PASSWORD`
- **Redis**: `REDIS_PASSWORD`

### Service Variables
- **n8n**: `N8N_ENCRYPTION_KEY`, `N8N_BASIC_AUTH_*`
- **Chatwoot**: `CHATWOOT_SECRET_KEY_BASE`, `CHATWOOT_API_TOKEN`
- **Directus**: `DIRECTUS_SECRET`, `DIRECTUS_KEY`
- **Evolution API**: `EVOLUTION_API_KEY`, `EVOLUTION_JWT_SECRET`
- **Lowcoder**: `LOWCODER_ENCRYPTION_PASSWORD`, `LOWCODER_ENCRYPTION_SALT`

## Change Procedure

When modifying environment variables:

1. **Update .env.example** first - this is the source of truth
2. **Update docker-compose.yml** if changing service references
3. **Update CI workflow** in `.github/workflows/ci.yml`:
   - Add to service validation section if needed
   - Add to integration tests section if needed
   - Include in critical variable validation list
4. **Update documentation** references in relevant service guides
5. **Test locally** before committing

## CI Integration Points

### Service Validation (Matrix Strategy)
- Location: `.github/workflows/ci.yml` lines 226-316
- Tests individual services in isolation
- Must include all required environment variables

### Integration Tests
- Location: `.github/workflows/ci.yml` lines 332-375
- Tests full stack deployment
- Uses `.env.example` as template with CI-specific values
- Includes critical variable validation

## Variable Validation

The CI pipeline validates that critical variables are:
- Present in the generated `.env` file
- Not set to placeholder values (`CHANGE_ME`)
- Not set to template values (`<...>`)

## Common Issues

### Missing Variables
- Error: `"The XXX variable is not set. Defaulting to a blank string."`
- Fix: Add variable to both service validation and integration test sections

### Naming Inconsistencies
- Error: Service fails to start due to missing environment variable
- Fix: Ensure variable name matches between `.env.example`, `docker-compose.yml`, and CI workflow

### Placeholder Values
- Error: Service starts but fails authentication/initialization
- Fix: Ensure CI sed commands properly replace all placeholder values

## Troubleshooting

1. **Check CI logs** for specific variable missing errors
2. **Compare .env.example vs CI workflow** for naming differences
3. **Verify docker-compose.yml** references correct variable names
4. **Run integration tests locally** with same environment setup

## Prevention Checklist

Before committing environment variable changes:

- [ ] Updated `.env.example` with new variables
- [ ] Updated `docker-compose.yml` service references
- [ ] Added variables to CI service validation section
- [ ] Added variables to CI integration tests section
- [ ] Included variables in critical validation list
- [ ] Updated relevant documentation
- [ ] Tested locally with bootstrap script
- [ ] Verified CI passes on test run

## Recent Changes

**2025-10-15**: Fixed MongoDB environment variable inconsistency
- Changed `.env.example`: `MONGO_INITDB_ROOT_PASSWORD` → `MONGODB_ROOT_PASSWORD`
- Updated CI integration tests to properly set MongoDB root password
- Added critical environment variable validation before docker compose up
- Created test results/logs directories to prevent CI upload warnings