# Hello CI/CD: React + GitHub Actions + Argo CD

A practice project for learning CI/CD with a GitOps workflow. It uses only free tools.

## How it works

```
 you push code
      │
      ▼
┌──────────────────────── GitHub Actions ────────────────────────┐
│ 1. test            lint → unit tests → build      (every PR)   │
│ 2. build-and-push  docker build → ghcr.io/you/hello-cicd:sha-… │
│ 3. update-manifest write new tag into k8s/deployment.yaml      │
│                    and commit it back to the repo   (main only)│
└────────────────────────────────────────────────────────────────┘
      │  (Git now says "run image sha-abc1234")
      ▼
┌──────────── your local kind cluster ────────────┐
│ Argo CD watches the k8s/ folder of the repo,    │
│ sees the new commit and rolls out the new image │
└─────────────────────────────────────────────────┘
```

Notice that the pipeline never connects to your cluster. Argo CD **pulls** changes from Git, which is the core idea of GitOps. That's also why a cluster on your laptop works: GitHub never needs to reach it.

| Piece | Tool | Cost |
|---|---|---|
| Code hosting | GitHub (public repo) | Free |
| CI/CD runner | GitHub Actions | Free for public repos |
| Image registry | GitHub Container Registry (ghcr.io) | Free for public images |
| Kubernetes | kind (Kubernetes in Docker) on your machine | Free |
| CD / GitOps | Argo CD | Free, open source |

## Repo layout

```
src/                      React app (App.jsx) and its test (App.test.jsx)
Dockerfile, nginx.conf    Multi-stage build: Node builds the app, nginx serves it
.github/workflows/        The CI/CD pipeline
k8s/                      Deployment + Service (what Argo CD deploys)
argocd/application.yaml   Tells Argo CD what to watch and where to deploy
```

---

## Step 0: Install the prerequisites

- **Git** and a **GitHub account**
- **Node.js 22 or newer** (only needed to run the app locally)
- **Docker Desktop**, Rancher Desktop or plain Docker on Linux. On Windows, use WSL2.
- **kubectl**
- **kind**: `brew install kind`, `choco install kind`, or see https://kind.sigs.k8s.io/docs/user/quick-start/

Check that the app works locally:

```bash
npm install
npm test        # should print "1 passed"
npm run dev     # open the URL it prints
```

## Step 1: Push the repo to GitHub

Create a **public** repository named `hello-cicd` on GitHub, with no README or .gitignore. Then run:

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/hello-cicd.git
git push -u origin main
```

Open the **Actions** tab. All three jobs should go green, and a new commit from `github-actions[bot]` will appear that updates `k8s/deployment.yaml`.

> If `update-manifest` fails with a 403 error, go to **Settings → Actions → General → Workflow permissions** and choose **Read and write permissions**.

## Step 2: Make the image public

GHCR makes new images private by default, and your cluster has no credentials to pull a private image.

1. On your GitHub profile, open **Packages → hello-cicd**.
2. Go to **Package settings → Change visibility → Public**.

You only need to do this once.

## Step 3: Create a local cluster and install Argo CD

```bash
kind create cluster --name cicd

kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# wait until every pod is Running (takes 1–2 minutes)
kubectl get pods -n argocd -w
```

Open the Argo CD UI:

```bash
# get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# in a separate terminal
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Go to https://localhost:8080. Accept the self-signed certificate warning and log in as `admin` with the password above.

## Step 4: Point Argo CD at your repo

Edit `argocd/application.yaml` and replace `YOUR_GITHUB_USERNAME`. Commit and push that change, then run:

```bash
kubectl apply -f argocd/application.yaml
```

In the UI, the `hello-cicd` app should turn **Synced** and **Healthy**. To see the site:

```bash
kubectl port-forward -n hello-cicd svc/hello-cicd 8081:80
```

Open http://localhost:8081 and you should see **Hello, World!**

## Step 5: Run the full loop

This is the part that teaches you CI/CD.

1. Create a branch: `git checkout -b new-message`
2. In `src/App.jsx`, change `MESSAGE` to something else, for example `'Hello, CI/CD!'`.
3. Push the branch and open a pull request. **CI fails**, because the test still expects "Hello, World!". This is CI catching a breaking change before it ships.
4. Update the expected text in `src/App.test.jsx`, push again, and watch CI go green.
5. Merge the PR. The pipeline builds a new image and commits the new tag.
6. Argo CD checks Git about every 3 minutes. To see the change sooner, click **Refresh** in the UI. Watch the pods roll over, then reload http://localhost:8081.

## Exercises to try next

- **Roll back:** `git revert` the bot's last deploy commit and push. Argo CD rolls back to the previous image, which is GitOps rollback in one command.
- **Watch self-heal:** `kubectl scale deploy hello-cicd -n hello-cicd --replicas=5`, then see Argo CD put it back to 2, the number written in Git.
- **Protect main:** add a branch protection rule that requires the `test` job to pass before merging.
- **Scan for vulnerabilities:** add a Trivy step to the `build-and-push` job.
- **Add a second environment:** create `k8s/staging` and `k8s/prod` with Kustomize, plus a second Argo CD Application.
- **Replace the commit-back step:** try Argo CD Image Updater, which watches the registry instead.

## Clean up

```bash
kind delete cluster --name cicd
```
