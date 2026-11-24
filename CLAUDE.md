# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A practice project for learning CI/CD with GitOps. The app itself is a minimal React 19 + Vite page. The real subject is the pipeline: GitHub Actions builds an image, pushes it to GHCR, and commits the new image tag back to `k8s/deployment.yaml`. Argo CD, running in a local kind cluster, watches `k8s/` and pulls in the change. The pipeline never connects to the cluster.

## Commands

```bash
npm install
npm run dev                    # Vite dev server
npm run lint                   # ESLint (flat config, eslint.config.js)
npm test                       # vitest run (jsdom, setup in src/setupTests.js)
npx vitest run src/App.test.jsx            # single test file
npx vitest run -t "shows the hello world"  # single test by name
npm run build                  # outputs to dist/
docker build -t hello-cicd .   # multi-stage: node:24-alpine build → nginx:alpine serve
```

CI (`.github/workflows/ci-cd.yml`) runs `npm ci && npm run lint && npm test && npm run build` on Node 24. Run the same steps locally to check that CI will pass.

## Architecture / how the pieces connect

- **`src/App.jsx`** exports `MESSAGE`, and **`src/App.test.jsx`** checks that the h1 contains that exact text, written out as a literal string. This is deliberate. Changing `MESSAGE` without updating the test makes CI fail, which is the teaching exercise in README Step 5.
- **Workflow jobs:** `test` runs on every PR and every push to main. `build-and-push` runs on main only, builds a multi-arch (amd64/arm64) image, and tags it `ghcr.io/<owner lowercased>/hello-cicd:sha-<7 chars>`. `update-manifest` runs on main only and rewrites the image tag with `sed`, then commits as `github-actions[bot]` with `[skip ci]`.
- **The `sed` in `update-manifest` rewrites every line matching `image:` in `k8s/deployment.yaml`.** If you add a second container or another `image:` line to that file, change the bump step to match.
- **Pushes that only touch `k8s/**`, `argocd/**` or `**.md` don't trigger the workflow** (`paths-ignore`). This prevents the bot's commit from looping. It also means a manifest-only change never goes through CI.
- `k8s/deployment.yaml` uses `nginx:alpine` as a placeholder until the first pipeline run. After that, the bot owns the `image:` line, so don't edit it by hand except to roll back on purpose.
- **`argocd/application.yaml`** syncs `k8s/` on `main` into the `hello-cicd` namespace with `prune` and `selfHeal` on, so manual `kubectl` changes get reverted. Its `repoURL` contains the placeholder `YOUR_GITHUB_USERNAME`, which must be replaced before you apply it.
- **`nginx.conf`** falls back to `index.html` for SPA routing. The k8s readiness and liveness probes hit `/` on port 80.
- **`.dockerignore`** keeps `k8s/`, `argocd/`, `.github/` and `*.md` out of the build context.
