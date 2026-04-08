# Pipeline Templates

## Node.js Basic

```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS == null

stages: [install, lint, test, build, deploy]

default:
  image: node:20-alpine

variables:
  NODE_ENV: "production"
  NPM_CONFIG_CACHE: "$CI_PROJECT_DIR/.npm"

cache:
  key:
    files: [package-lock.json]
  paths: [node_modules/, .npm/]

install:
  stage: install
  script: [npm ci]
  artifacts:
    paths: [node_modules/]
    expire_in: 1 hour

lint:
  stage: lint
  needs: [install]
  script: [npm run lint]

test:
  stage: test
  needs: [install]
  script: [npm test -- --coverage]
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
    expire_in: 30 days

build:
  stage: build
  needs: [lint, test]
  script: [npm run build]
  artifacts:
    paths: [dist/]
    expire_in: 1 week
    access: developer
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "develop"'

deploy:
  stage: deploy
  needs: [build]
  script: [echo "Deploying..."]
  environment:
    name: production
    url: https://example.com
  resource_group: production
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
```

## Node.js Multi-Stage (Staging + Production + Review Apps)

```yaml
image: node:20-alpine
stages: [install, lint, test, build, deploy]

variables:
  NODE_ENV: "production"
  NPM_CONFIG_CACHE: "$CI_PROJECT_DIR/.npm"

cache:
  key:
    files: [package-lock.json]
  paths: [node_modules/, .npm/]

install:
  stage: install
  script: [npm ci]
  artifacts:
    paths: [node_modules/]
    expire_in: 1 hour

lint:
  stage: lint
  needs: [install]
  script: [npm run lint, npm run check-types]

test:unit:
  stage: test
  needs: [install]
  script: [npm run test:unit -- --coverage]
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'

test:integration:
  stage: test
  needs: [install]
  script: [npm run test:integration]

build:
  stage: build
  needs: [lint, test:unit, test:integration]
  script: [npm run build]
  artifacts:
    paths: [dist/, .next/, public/]
    expire_in: 1 week

deploy:staging:
  stage: deploy
  needs: [build]
  script: [echo "Deploy staging..."]
  environment:
    name: staging
    deployment_tier: staging
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'

deploy:production:
  stage: deploy
  needs: [build]
  script: [echo "Deploy production..."]
  environment:
    name: production
    deployment_tier: production
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual

deploy:review:
  stage: deploy
  needs: [build]
  script: [echo "Deploy review app..."]
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop:review
    auto_stop_in: 1 week
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

stop:review:
  stage: deploy
  script: [echo "Cleanup review..."]
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

## Docker Build & Push

```yaml
image: docker:24-cli
services: [docker:24-dind]

variables:
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_CERTDIR: "/certs"
  DOCKER_TLS_VERIFY: 1
  DOCKER_CERT_PATH: "$DOCKER_TLS_CERTDIR/client"
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  LATEST_TAG: $CI_REGISTRY_IMAGE:latest

stages: [build, test, push, deploy]

build:image:
  stage: build
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $IMAGE_TAG -t $LATEST_TAG .
    - docker push $IMAGE_TAG
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "develop"'
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

test:image:
  stage: test
  needs: [build:image]
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker pull $IMAGE_TAG
    - docker run --rm $IMAGE_TAG npm test

push:latest:
  stage: push
  needs: [test:image]
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker pull $IMAGE_TAG
    - docker tag $IMAGE_TAG $LATEST_TAG
    - docker push $LATEST_TAG
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

push:release:
  stage: push
  needs: [test:image]
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker pull $IMAGE_TAG
    - docker tag $IMAGE_TAG $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
  rules:
    - if: $CI_COMMIT_TAG
```
