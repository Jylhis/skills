---
name: gitlab-cicd
description: "GitLab CI/CD pipeline configuration and .gitlab-ci.yml patterns. Use when editing .gitlab-ci.yml files, debugging pipeline failures, creating CI/CD components, configuring downstream pipelines, setting up Docker builds, managing caching strategies, or writing reusable pipeline templates. Also triggers for duplicate pipeline issues, YAML merge traps, runner configuration, artifacts vs cache questions, pipeline inputs, and CI/CD Catalog components."
user-invocable: false
---

GitLab CI/CD pipeline configuration -- YAML gotchas, components, templates, and best practices.

## CI/CD YAML Gotchas

These are the most common pitfalls when writing `.gitlab-ci.yml`. Each one has caused real production issues.

### Rules Gotchas
- `rules:` and `only:/except:` cannot mix -- use one or the other per job
- First matching rule wins -- put specific rules before general ones
- Missing `when:` defaults to `on_success` -- `rules: - if: $CI_COMMIT_TAG` runs on tag pushes
- Empty rules array `rules: []` means never run -- different from no rules at all
- Add `- when: never` at end to prevent fallthrough -- otherwise unmatched conditions may run

### Silent Failures
- Protected variables missing on non-protected branches -- job runs but variable is empty
- Runner tag mismatch -- job stays pending forever with no error
- `docker:dind` on non-privileged runner -- fails with cryptic Docker errors
- Masked variable format invalid -- variable exposed in logs anyway

### YAML Merge Traps
- `extends:` does not deep merge arrays -- scripts and variables arrays get replaced, not appended
- Use `!reference [.job, script]` to reuse: `script: [!reference [.base, script], "my command"]`
- `include:` files can override each other -- last one wins for same keys
- Anchors `&`/`*` do not work across files -- use `extends:` for cross-file reuse

### Artifacts vs Cache
- Cache is not guaranteed between runs -- treat as optimization, not requirement
- Artifacts auto-download by stage -- add `dependencies: []` to skip if not needed
- `needs:` downloads artifacts by default -- `needs: [{job: x, artifacts: false}]` to skip

### Docker-in-Docker
- Shared runners usually do not support privileged mode -- need self-hosted or special config
- `DOCKER_HOST: tcp://docker:2375` required -- job uses wrong Docker otherwise
- `DOCKER_TLS_CERTDIR: ""` or configure TLS properly -- half-configured TLS breaks builds

### Pipeline Triggers
- `CI_PIPELINE_SOURCE` differs by trigger: `push`, `merge_request_event`, `schedule`, `api`, `trigger`, `pipeline`, `parent_pipeline`
- MR pipelines need `rules: - if: $CI_MERGE_REQUEST_IID` -- not just branch rules
- Detached vs merged result pipelines -- detached tests source, merged tests the merge result
- Use `"pipeline"` for multi-project triggers, `"parent_pipeline"` for parent-child

### Duplicate Pipelines
Without `workflow:rules`, both a branch pipeline AND MR pipeline run for the same push:
```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS == null
```

### Deprecated Patterns
- Globally-defined `image`, `services`, `cache`, `before_script`, `after_script` -- use `default:` section
- `artifacts:public` -- replaced by `artifacts:access` (`developer`, `maintainer`, `none`, `all`)
- `only:/except:` -- replaced by `rules:` (more flexible)
- Unquoted numeric variables -- `VAR: 012345` becomes octal (5349). Always quote: `VAR: "012345"`

### Component / Input Gotchas
- Empty `spec:inputs:` causes error -- use empty `spec:` instead if no inputs needed
- `~latest` version only works with published catalog resources, not during development
- Max 100 components per project, max 150 includes per pipeline
- Jobs with identical names silently merge when including multiple components -- use `job-prefix` inputs

## CI/CD Components & Reusable Pipelines

CI/CD components are reusable, versioned pipeline configuration units published to the CI/CD Catalog (GA since GitLab 17.0).

### Using Components

```yaml
include:
  - component: $CI_SERVER_FQDN/my-org/security-scanning/sast@1.0.0
    inputs:
      stage: test
      scan_level: "high"
```

**Version pinning:** commit SHA > tag > branch > partial semver (`1.0`, `1`) > `~latest`. Use tags in production.

### Creating Components

Components live in `templates/` -- one YAML file per component, or a directory with `template.yml`:

```
my-components/
├── templates/
│   ├── lint.yml                    # single-file component
│   └── deploy/
│       └── template.yml            # directory-based component
├── README.md
└── .gitlab-ci.yml
```

### Spec & Inputs

Define inputs with `spec:` and reference them with `$[[ inputs.name ]]`:

```yaml
spec:
  description: "Deploys to a target environment"
  inputs:
    environment:
      type: string
      default: "staging"
      options: ["staging", "production"]
    enable_tests:
      type: boolean
      default: true
    job-prefix:
      description: "Prefix for job names to avoid conflicts"
      default: ""
---
"$[[ inputs.job-prefix ]]deploy":
  stage: deploy
  script: deploy --env $[[ inputs.environment ]]
  rules:
    - if: $[[ inputs.enable_tests ]]
```

**Component context (18.6+):** Access `$[[ component.name ]]`, `$[[ component.version ]]`, `$[[ component.sha ]]` after declaring in `spec:component:`.

### Conditional Includes

```yaml
include:
  - local: build_jobs.yml
    rules:
      - if: $INCLUDE_BUILDS == "true"
  - remote: 'https://example.com/template.yml'
    integrity: 'sha256-L3/GAoKaw0Arw6...'
```

## Downstream Pipelines

### Parent-Child (same project)

```yaml
trigger-child:
  trigger:
    include:
      - local: path/to/child-pipeline.yml
    strategy: depend     # parent waits for child to finish
```

Max 2 levels of child nesting. Up to 3 `include` files combinable.

### Multi-Project

```yaml
trigger-downstream:
  trigger:
    project: other-group/other-project
    branch: main
    strategy: depend
```

Masked variables do NOT forward to multi-project pipelines.

### Dynamic Child Pipelines

```yaml
generate-config:
  stage: build
  script: python generate_pipeline.py > generated.yml
  artifacts:
    paths: [generated.yml]

run-generated:
  stage: test
  trigger:
    include:
      - artifact: generated.yml
        job: generate-config
    strategy: depend
```

### Variable Forwarding

```yaml
trigger-child:
  trigger:
    include: [local: child.yml]
    forward:
      pipeline_variables: true    # manual/API variables
      yaml_variables: true        # variables from this job
```

### Pipeline Inputs (GA 18.1)

More secure than pipeline variables -- type-checked and scoped:

```yaml
spec:
  inputs:
    deploy_target:
      type: string
      options: ["staging", "production"]
    replicas:
      type: number
      default: 3
---
deploy:
  script: deploy --target $[[ inputs.deploy_target ]] --replicas $[[ inputs.replicas ]]
```

## Pipeline Best Practices

### Prevent Duplicate Pipelines
```yaml
workflow:
  name: 'Pipeline for $CI_COMMIT_BRANCH'
  auto_cancel:
    on_new_commit: interruptible
  rules:
    - if: $CI_COMMIT_REF_PROTECTED == 'true'
      auto_cancel:
        on_new_commit: none
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS == null
```

### Caching Strategies

```yaml
# Cache based on lockfile hash
cache:
  key:
    files: [package-lock.json]
  paths: [node_modules/, .npm/]
  fallback_keys:
    - "$CI_COMMIT_REF_SLUG"
    - default

# Split cache policies
install:
  cache:
    policy: pull-push     # Update cache
test:
  cache:
    policy: pull          # Read only
```

### Resource Groups (Deployment Safety)

Prevent concurrent deployments:
```yaml
deploy:production:
  resource_group: production
  environment:
    name: production
```

**Process modes:** `unordered` (default), `oldest_first`, `newest_first` (best for deploys), `newest_ready_first`

### Secrets & OIDC

Use `id_tokens` for OIDC-based auth with Vault/AWS/GCP/Azure -- avoids storing long-lived secrets:

```yaml
deploy:
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com
  secrets:
    DATABASE_PASSWORD:
      vault:
        engine: { name: kv-v2, path: secret }
        path: production/db
        field: password
      file: false           # expose as env var, not file
```

Unlike CI/CD variables (always available), secrets must be explicitly requested per job.

### Performance Optimization

1. **Fail fast:** Quick checks (lint ~30s) before expensive ones (build ~5m)
2. **Parallelize:** Independent jobs run simultaneously via `needs:` DAG
3. **Smaller images:** `node:20-alpine` vs `node:20`
4. **Optimize artifacts:** Set `expire_in`; use `access: developer`; add `dependencies: []` to skip
5. **Cache aggressively:** Dependencies and build caches; use `policy: pull` for parallel readers
6. **Use `interruptible: true`** + `workflow:auto_cancel` to cancel redundant pipelines
7. **Use `default:`** section instead of globally-defined image/services/cache

### Common Patterns

```yaml
# Matrix builds
test:
  parallel:
    matrix:
      - NODE_VERSION: ["18", "20", "22"]
  image: node:${NODE_VERSION}

# Auto-retry on infrastructure failures
test:flaky:
  retry:
    max: 2
    when: [runner_system_failure, stuck_or_timeout_failure]

# Review apps with auto-cleanup
review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop:review
    auto_stop_in: 1 week
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

# Manual confirmation for production
deploy:production:
  environment:
    name: production
    deployment_tier: production
  resource_group: production
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
      manual_confirmation: "Deploy to production?"

# Optional dependency (proceeds if dependency fails/skipped)
final-report:
  needs:
    - job: flaky-test
      optional: true
    - job: stable-test

# Run immediately without stage ordering
notify:
  needs: []
  script: echo "Pipeline started"
```

### Security Scanning

```yaml
# GitLab SAST + Secret Detection
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml

# npm audit
security:audit:
  script: [npm audit --audit-level=high --production]
  allow_failure: true
```

For complete pipeline templates (Node.js, Docker), see [references/pipeline-templates.md](references/pipeline-templates.md).

## Decision Trees

### Reuse Pipeline Config

```
Sharing CI/CD logic across projects?
+- Same project         -> extends: or include: local:
+- Across projects      -> CI/CD Component (CI/CD Catalog)
+- One-off share        -> include: project: or include: remote:
+- Dynamic generation   -> Dynamic child pipeline (artifact + trigger)
```

### Which Pipeline Type?

```
What triggers the pipeline?
+- Code push            -> CI_PIPELINE_SOURCE == "push"
+- MR created/updated   -> CI_PIPELINE_SOURCE == "merge_request_event"
+- Scheduled            -> CI_PIPELINE_SOURCE == "schedule"
+- API call             -> CI_PIPELINE_SOURCE == "api"
+- Parent pipeline      -> CI_PIPELINE_SOURCE == "parent_pipeline"
+- Multi-project        -> CI_PIPELINE_SOURCE == "pipeline"
```

## Related Skills

- `glab` -- CLI workflow automation, merge requests, issues, epics
