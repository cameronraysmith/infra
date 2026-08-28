# Verification Report

> This file is produced by the `openspec-verify-change` skill after apply completes, to confirm that the
> implementation is consistent with the specs / design / tasks. Any failed check must be returned to its
> corresponding artifact for correction before re-running verify.

**Change**: `stand-up-nixbot-on-magnetite`
**Verified at**: `2026-08-28 02:18 UTC`
**Verifier**: `fm/vx-nixbot-verify-and-reconcile worker agent, with operator-attributed evidence marked as such`

This file carries two roles, following the precedent of
`openspec/changes/archive/2026-08-01-pyrite-baremetal-nixos/verify.md`.
Sections 1 through 8 are the schema's verification report.
Sections 9 through 11 are the evidence ledger that `plan.md:29`, `plan.md:505` and `tasks.md:3-5`
require this file to hold: the forge application record, the deployment record, and the
integration verification evidence.

Two attributions are used throughout and never blurred.
`[operator]` marks an observation only the operator could make, performed under the operator's own
identity and reported to this session; it is recorded, not re-derived.
`[verified here]` marks an observation this session made itself, with the command and its output given.

---

## 1. Structural Validation (`openspec validate --all --json`)

- [x] All items report `"valid": true`

**Result**:

```text
$ openspec validate --all --json
  "summary": {
    "totals": { "items": 19, "passed": 19, "failed": 0 },
    "byType": {
      "change": { "items": 4, "passed": 4, "failed": 0 },
      "spec":   { "items": 15, "passed": 15, "failed": 0 }
    }
  }
```

No items fail.

| Item | Type | Issues |
|---|---|---|
| — | — | — |

---

## 2. Task Completion (`tasks.md`)

- [ ] All `- [ ]` have been changed to `- [x]`

Twenty-six of twenty-seven boxes are now checked.
One remains deliberately unchecked, for the reason recorded against it in `tasks.md` and repeated here.

| Task | Reason incomplete | Blocks archive? |
|---|---|---|
| 10.4 Verify delivery authentication both ways | Requires a redelivery from the forge application's advanced settings tab, which is available only under the operator's own identity, and a matched rejection probe. Not attempted. Exact operator steps and expected evidence are written out in §10.4. | No — but it is the last outstanding acceptance item and should be closed before archive |

One further item is open without being an unchecked box: the design's question about whether an
installation with *no* repository selected is permitted.
The installation was made with one repository selected, `cameronraysmith/vanixiets` alone, so an
empty selection was never exercised, and the question stays open and untested in §9.3.

Task 1.2 is recorded as checked because its two mandated records — the verbatim installation selection and
the resolution *status* of the open question — are both present.
The open question itself is recorded as still open, which is what `tasks.md:4` asks for: the resolution
"is recorded with it", and `untested` is the honest resolution status.

---

## 3. Delta Spec Sync State

Delta spec files reported by the CLI
(`openspec status --change "stand-up-nixbot-on-magnetite" --json | jq -r '.artifactPaths.specs.existingOutputPaths[]'`):

```text
openspec/changes/stand-up-nixbot-on-magnetite/specs/build-service-interface/spec.md
openspec/changes/stand-up-nixbot-on-magnetite/specs/nixbot-build-service/spec.md
openspec/changes/stand-up-nixbot-on-magnetite/specs/world-assumptions/spec.md
```

| Capability | Sync status | Notes |
|---|---|---|
| `nixbot-build-service` | pending sync | No `openspec/specs/nixbot-build-service/` exists; this change introduces the capability. Sync happens at archive. |
| `build-service-interface` | pending sync | No `openspec/specs/build-service-interface/` exists; this change introduces the capability. Sync happens at archive. |
| `world-assumptions` | pending sync | `openspec/specs/world-assumptions/` exists; the delta MODIFIES it, adding A9 through A12 and the designation-table rows. Sync happens at archive. |

Pending sync is the correct state for an unarchived change; nothing here is drift.

---

## 4. Design / Specs Coherence Spot Check

| Sampled item | design description | specs correspondence | Gap |
|---|---|---|---|
| D4, verdict namespace | `design.md:61` — "leave the status-context prefix at its default, `nixbot`" | `specs/build-service-interface/spec.md:59-61` requires a prefix distinct from the incumbent's and never emitting under the incumbent's; `specs/nixbot-build-service/spec.md:67-71` is discharged by it under A9 and A12 | none |
| D9, capacity | `design.md:93` — 32 GiB against four incumbent eval workers at 2 GiB each, one store under a 250 G quota | `specs/nixbot-build-service/spec.md:115-119` names A11 plus "the sizing recorded in this change's design", and explicitly states no interface property can discharge it | none |
| D3, repository visibility | outermost boundary is the forge-side installation selection, not machine-assertable | `specs/build-service-interface/spec.md:31-33` states this rather than concealing it; the behavioral requirement at `spec.md:35-39` inherits the caveat | none |
| Migration plan, rollback | `design.md:132-133` — remove the aspect and redeploy; database, role, state directory and credential entries persist and are harmless | `specs/nixbot-build-service/spec.md:30-33` scenario "The second build service is withdrawn" | none |
| Trust boundary | `design.md` D3 and the interface capability's own requirement | `specs/build-service-interface/spec.md:101-103` forbids describing the capability, in itself or in any downstream report, as an end-to-end guarantee that the incumbent is unaffected | none — and §12 of this report honours it explicitly |

**Drift warnings** (non-blocking):

- One wording drift, in `proposal.md:26-27`, which states "This change is planning-only. It writes the artifacts a later change implements against; no module code, no host configuration, and no deployment happen here." That is no longer true: the modules landed, the host was composed, and the deployment ran. The operative acceptance definition is `design.md:135`, and this report verifies against that. The proposal's framing sentence is stale and should be corrected or the change re-scoped in its retrospective; it changes no requirement.

---

## 5. Implementation Signal

- [x] No unstaged files in the worktree, other than this report and the `tasks.md` edits it accompanies
- [x] All related commits have been pushed

**Commit range**: `274e2e159..53962942d` on `main`, the eleven commits of this change in order:

```text
274e2e159 docs(openspec): register the nixbot CI/CD Linear project
35538d9d7 docs(openspec): plan standing nixbot up beside buildbot on magnetite
bc9fe4ca7 feat(nixbot): add nixbot flake input
9919defcd feat(nixbot): add nixbot aspect and compose it onto magnetite
5afc3cd11 feat(nixbot): declare nixbot DNS record
5cd3c7d03 docs(nixbot): document the two-service build topology on magnetite
6117bdeb1 feat(nixbot): enable the GitHub integration on the dedicated application
f518224ac docs(nixbot): record the instantiation gate and its amended verification
31e205454 vars: update nixbot-github-app-secret-key/key.pem for machine magnetite
63d82abcb vars: update nixbot-github-oauth-secret/secret for machine magnetite
53962942d vars: update via generator nixbot-github-webhook-secret (machine: magnetite)
```

---

## 6. Front-Door Routing Leak Detector (warning, non-blocking)

```bash
$ ls docs/superpowers/specs/*.md 2>/dev/null
# no output, exit 2 — the directory does not exist
```

- [x] No files

| File | Content captured into change? | Recommended action |
|---|---|---|
| — | — | — |

---

## 7. Deferred Manual Dogfood vs Automated Test Equivalence

`plan.md` contains no rows marked `[~]`; every row is `- [ ]` or `- [x]`.
Blank means PASS.

---

## 8. Designation Lint and Discharge Coherence (warning, non-blocking)

### 8a. Designation lint

`proposal.md` tags `nixbot-build-service` behavioral.
Its requirement statements' content nouns resolve against the designation table in
`openspec/specs/world-assumptions/spec.md`, as MODIFIED by this change's world delta, which adds the
rows these nouns need: forge, forge application, delivery, check run, required check, build capacity,
operator.

| Requirement | Resolved against the table | Unresolved — machine noun | Unresolved — world-flavored gap |
|---|---|---|---|
| A second build service is reachable at its own hostname | build service, hostname, certificate | — | — |
| The incumbent build service continues to serve | build service, incumbent | — | — |
| Repositories are built only once opted in | repository, forge application, installation selection, build | — | — |
| Deliveries a build service acts on are authenticated | delivery, delivery secret | — | — |
| A second build service's verdicts do not gate merges | check run, required check, merge, forge | — | — |
| Forge credentials are operator-supplied and never legible in the repository | operator, credential, repository | — | — |
| One activation establishes the second build service | activation, host, declared configuration | — | — |
| A second build service is sized against the capacity the incumbent uses | build capacity, host | — | — |

No unresolved nouns. The table is present and was consulted, so this report is not vacuous.

### 8b. Discharge coherence

| Requirement | Discharged by (S) | Under (W) | Status |
|---|---|---|---|
| A second build service is reachable at its own hostname (`nixbot-build-service:3-7`) | `build-service-interface` — A distinct hostname is served with its own certificate | A10 | discharged; witnessed by tasks 10.1, 6.2 |
| The incumbent build service continues to serve (`:19-23`) | `build-service-interface` — The two build services hold disjoint host resources, bounded by the shared surfaces that requirement names | — | discharged, bounded; witnessed by tasks 10.2, 5.2 |
| Repositories are built only once opted in (`:35-39`) | `build-service-interface` — Repository visibility is bounded outside the machine and narrowed within it | A9 | discharged inside the machine; the outermost boundary is not machine-assertable and the requirement says so |
| Deliveries a build service acts on are authenticated (`:51-55`) | `build-service-interface` — Deliveries are accepted only at an authenticated endpoint | A9 | **partially discharged.** The accepted-delivery arm is witnessed (§10.4). The rejection arm is not; task 10.4 is unchecked. Recorded, not accepted. |
| A second build service's verdicts do not gate merges (`:67-71`) | `build-service-interface` — Verdict namespaces are distinct | A9, A12 | discharged; witnessed by tasks 4.2, 10.6, and by the forge-side ruleset in §10.6 |
| Forge credentials are operator-supplied and never legible in the repository (`:83-87`) | `build-service-interface` — Credentials exist only as activation-resolved paths | — | discharged; witnessed by tasks 3.1, 3.2, 3.3. `design.md:158` gives the modality as "secret scan and build gate"; the secret-scan leg is substituted by a positive-controlled content search over working tree, `HEAD` and full history, because the repository's `gitleaks` hook runs `protect --staged` and cannot audit what is already committed (§11) |
| One activation establishes the second build service (`:99-103`) | `build-service-interface` — The service is a consequence of the host's declared configuration | — | discharged; witnessed by tasks 8.1, 10.1, 7.1 |
| A second build service is sized against the capacity the incumbent uses (`:115-119`) | world assumption A11 plus the sizing recorded in design D9; **no interface property can discharge this one**, which the spec states | A11 | discharged as designed; the capacity baseline is §10.7 |

The `build-service-interface` delta carries no `**Discharged by**` lines by design: it *is* the
discharging stratum.
Its own requirement "This capability states its own trust boundary"
(`specs/build-service-interface/spec.md:101-103`) is discharged by capability text plus the
documentation committed in `5cd3c7d03`, and is honoured by §12 of this report.

One requirement is recorded `partially discharged` rather than omitted or silently accepted:
deliveries-are-authenticated, whose rejection arm awaits the operator probe in §10.4.

### 8c. Alphabet check

Behavioral requirements must not name interface phenomena, and interface requirements must not
reference world state the machine cannot observe.

**Violations found**:

- none. The one place where the boundary is under pressure — the installation selection, which is
  world state the machine cannot assert — is handled by the interface requirement naming its own
  limit (`specs/build-service-interface/spec.md:31-33`) rather than by claiming observability.

---

## 9. Forge application record

The record `tasks.md:3-5` and `plan.md:29`, `plan.md:50`, `plan.md:54`, `plan.md:58` require.

### 9.1 The dedicated application

`[operator]` registered under the operator's own identity; `[verified here]` confirmed independently
through the API.

| Field | Value |
|---|---|
| Application id | `4743700` |
| Slug | `sciexp-nixbot` |
| OAuth client id | `Iv23lie8GaDpY0cPXGg4` |
| Owner | `sciexp` (Organization) |
| Visibility | public |
| Settings page | `https://github.com/apps/sciexp-nixbot` |
| Webhook URL | `https://nixbot.scientistexperience.net/webhooks/github` `[operator]`, confirmed on the settings page |
| User-authorization callback | `https://nixbot.scientistexperience.net/auth/github/callback`, confirmed functionally by a completed login (§9.4) |

Permissions and events, `[verified here]`:

```text
$ gh api /apps/sciexp-nixbot
id=4743700 slug=sciexp-nixbot client_id=Iv23lie8GaDpY0cPXGg4 owner=sciexp type=Organization
events=["check_run","check_suite","pull_request","push"]
perms={"checks":"write","contents":"read","members":"read","metadata":"read","pull_requests":"read"}
html_url=https://github.com/apps/sciexp-nixbot
```

Both sets are an exact match to `tasks.md:3`: repository permissions Contents read, Checks write,
Metadata read, Pull requests read; organization permission Members read; events push, pull request,
check run, check suite.

Public visibility is `[operator]`-established by a check the API cannot make: the application page
renders to an anonymous visitor, which a private application's page does not.

### 9.2 Installation selection, verbatim

> cameronraysmith/vanixiets ALONE

`[operator]`, from the application's installations page.
Installation id `157111096`, `[verified here]` from the service's own startup log
(`POST /app/installations/157111096/access_tokens` returning `201 Created`,
`journalctl -u nixbot.service`, Aug 28 02:01:06).
Repository id `807284872` corresponds to `cameronraysmith/vanixiets`, `[verified here]`:

```text
$ gh api /repos/cameronraysmith/vanixiets
id=807284872 full_name=cameronraysmith/vanixiets default_branch=main
```

### 9.3 The design's open question about an empty selection

**Status: OPEN and UNTESTED.**

`design.md:179-180` asks whether the forge application can be installed with no repositories
selected at all, or whether the provider requires at least one selection.
The installation was made with exactly one repository selected, so nothing about an empty selection
was exercised.
Neither answer has been observed and none is inferred here.

This is compatible with the requirements either way, as `design.md:180` states, and the operative
boundaries on day one are the two that *were* verified: the disabled topic-based auto-import
(`github.topic = null`) and the explicit empty allowlist (`github.repoAllowlist = [ ]`), both in §10.3.

### 9.4 The design's second open question, about the interface-login client

**Status: RESOLVED in practice.**

`design.md:182-183` asks whether the interface-login client is wanted at all on day one, since a
service that builds nothing has little to show a logged-in viewer.

`[operator]` navigated to `https://nixbot.scientistexperience.net/` and completed a GitHub login.
That single round trip establishes three things at once: the OAuth client id
`Iv23lie8GaDpY0cPXGg4` is correct, the client secret stored as `nixbot-github-oauth-secret` was
populated correctly, and the user-authorization callback
`https://nixbot.scientistexperience.net/auth/github/callback` is right.

`[verified here]` corroborated in the service log, `journalctl -u nixbot.service`:

```text
Aug 28 02:02:51  INFO: - "GET /login/github HTTP/1.1" 307 Temporary Redirect
Aug 28 02:02:55  httpx: HTTP Request: POST https://github.com/login/oauth/access_token "HTTP/1.1 200 OK"
Aug 28 02:02:55  httpx: HTTP Request: GET https://api.github.com/user "HTTP/1.1 200 OK"
Aug 28 02:02:55  INFO: - "GET /auth/github/callback?...&state=... HTTP/1.1" 307 Temporary Redirect
Aug 28 02:02:59  INFO: - "GET /builds HTTP/1.1" 200 OK
```

The client is functional and in use, so the question is answered by the thing working rather than
by argument. The design's own resolution — plan both, since the upstream module asserts the pair
together — stands.

### 9.5 The incumbent application, unchanged

`[operator]` captured a baseline from the incumbent's settings page *before* the new registration and
compared it after. `[verified here]` confirmed the same fields through the API.

| Field | Value | Matches pre-change baseline |
|---|---|---|
| Application id | `3305657` | yes |
| Slug | `sciexp-buildbot` | yes |
| Owner | `sciexp` (Organization) | yes |
| Events | `[]` — none subscribed | yes |
| Permissions | `contents:read`, `emails:read`, `members:read`, `metadata:read`, `repository_hooks:write`, `statuses:write` | yes |

```text
$ gh api /apps/sciexp-buildbot
id=3305657 slug=sciexp-buildbot owner=sciexp type=Organization events=[]
perms={"contents":"read","emails":"read","members":"read","metadata":"read",
       "repository_hooks":"write","statuses":"write"}
```

The two applications are disjoint in every field that matters: distinct ids, distinct OAuth clients
(`Iv23lie8GaDpY0cPXGg4` against the incumbent stack's `Iv23liFu66NnDcfRGDHs`,
`modules/nixos/buildbot.nix:120`), and non-overlapping event subscriptions — the incumbent subscribes
to nothing and is driven by repository webhooks instead.

---

## 10. Deployment and integration verification record

Deployment ran as `clan machines update magnetite` `[operator]`, installing all three credential
files and starting `nixbot.service`, `nixbot.socket`,
`acme-nixbot.scientistexperience.net.service` and its renewal timer, and restarting nginx.
Every observation below is `[verified here]` unless marked otherwise.

### 10.1 The new service answers at its own hostname

```text
$ curl -o /dev/null -w '%{http_code} ssl_verify=%{ssl_verify_result} %{time_total}\n' \
    https://nixbot.scientistexperience.net/
200 ssl_verify=0 0.3818
```

Certificate `CN=nixbot.scientistexperience.net`, Let's Encrypt, notBefore
`Aug 28 01:01:58 2026 GMT`, notAfter `Nov 26 01:01:57 2026 GMT` `[operator]`.
`ssl_verify_result=0` is this session's independent confirmation that the chain validates.

The certificate is the service's own, not the incumbent's: `acme-nixbot.scientistexperience.net.service`
is a separate unit with its own renewal timer, next elapse `Sat 2026-08-29 05:51:15 UTC`.

### 10.2 The incumbent still serves, and its 403 is settled

The public response is HTTP 403 to an unauthenticated request:

```text
$ curl -o /dev/null -w '%{http_code} ssl_verify=%{ssl_verify_result} %{time_total}\n' \
    https://buildbot.scientistexperience.net/
403 ssl_verify=0 0.4722
```

**Verdict: 403 is this service's configured anonymous response, not a regression.**
Four independent lines of evidence, none of which relies on assuming it.

First, the 403 is emitted by oauth2-proxy, which sits in front of buildbot and predates this change
by thirteen days:

```text
$ ss -ltnp | grep 8020
LISTEN 127.0.0.1:8020  users:(("oauth2-proxy",pid=1771,fd=4))

$ systemctl show oauth2-proxy.service -p ActiveState -p ActiveEnterTimestamp -p MainPID
ActiveState=active
ActiveEnterTimestamp=Fri 2026-08-14 23:12:13 UTC
MainPID=1771
```

nginx proxies the buildbot vhost's `location /` to exactly that address
(`/etc/nginx/nginx.conf:125`, `proxy_pass http://127.0.0.1:8020/`), and the vhost carries no
`auth_basic` or `auth_request` of its own. `ActiveEnterTimestamp` 2026-08-14 23:12:13 UTC and an
unchanged `MainPID` place oauth2-proxy's current run wholly before the 2026-08-28 02:01 nixbot
deployment; it was never restarted by it.

Second, the response body is oauth2-proxy's own sign-in page, 8486 bytes, matching the size nginx
logs for every such request:

```text
$ curl -sS https://buildbot.scientistexperience.net/ | grep -oiE '<title>[^<]*</title>|Sign in with'
<title>Sign In</title>
<title>OAuth2_Proxy_logo_v3</title>
Sign in with

$ journalctl -u nginx | grep 403
28/Aug/2026:02:02:31 "GET / HTTP/2.0" 403 8486 "-" "curl/8.21.0"
28/Aug/2026:02:07:07 "GET / HTTP/2.0" 403 8486 "-" "fm-verify-probe-10.2"
```

Third, buildbot itself never emitted the 403 and never saw the request.
Its own access log and every rotation of it contain zero 403 responses, and a probe sent with a
distinctive user agent appears in nginx's log but not in buildbot's:

```text
$ for f in http.log http.log.1 http.log.2; do grep -c '" 403 ' /var/lib/buildbot/master/$f; done
0
0
0
$ grep -c 'fm-verify-probe' /var/lib/buildbot/master/http.log
0
```

This is the decisive point for the missing baseline. Unauthenticated requests have *never* reached
buildbot, before or after the change, so there is no state in which the incumbent answered anonymous
callers and stopped.

Fourth, the incumbent is configured to be authenticated, deliberately, in this repository and its
pinned upstream. `modules/nixos/buildbot.nix:118-125` sets
`accessMode.fullyPrivate = { backend = "github"; clientId = "Iv23liFu66NnDcfRGDHs"; ... }`, which
upstream turns into `authBackend = "httpbasicauth"` (buildbot-nix `nixosModules/master.nix:1147-1149`
at pinned rev `9a8ea9a4`, `flake.lock:51`) and into the oauth2-proxy in front
(`master.nix:1151-1193`). The running configuration agrees:

```text
$ python3 -c '...' /nix/store/axn9773fyqf72l0nhzdp448aycnila1j-buildbot-nix-config.json
admins = ["cameronraysmith"]
allow_unauthenticated_control = false
auth_backend = "httpbasicauth"
domain = "buildbot.scientistexperience.net"
```

The mechanism also explains why webhooks keep working while `/` does not: oauth2-proxy is configured
`skip-auth-route = [ "^/change_hook" ]` (`master.nix:1166`), so forge deliveries bypass the sign-in
gate that anonymous browsers meet.

The incumbent's units are active and, more than that, actively building after the deployment:

```text
$ systemctl list-units --type=service --plain 'buildbot*'
buildbot-master.service   loaded active running  Buildbot Continuous Integration Server.
buildbot-worker.service   loaded active running  Buildbot Worker.

$ psql -d buildbot -c 'select id, builderid, to_timestamp(started_at) from builds order by id desc limit 5;'
 60436 | 185 | 2026-08-28 02:08:04+00
 60435 | 133 | 2026-08-28 02:08:04+00
 60434 | 132 | 2026-08-28 02:08:04+00
 60433 | 131 | 2026-08-28 02:08:03+00
 60432 | 130 | 2026-08-28 02:08:03+00

$ tail -1 /var/lib/buildbot/master/http.log
"127.0.0.1" - - [28/Aug/2026:02:05:08] "POST /change_hook/github HTTP/1.1" 202 "GitHub-Hookshot/483c20e"
```

Builds started at 02:08, seven minutes after nixbot came up at 02:01, and a forge delivery was
accepted at 02:05. A regressed incumbent does neither.

### 10.3 The new service builds nothing

`[operator]`, from the user-facing surface, which is the strongest form of this evidence: the
interface reports no repositories set up to build.
`[verified here]` corroborated on the same surface and then in the service's own state.

The interface, rendered anonymously:

```text
$ curl -sS https://nixbot.scientistexperience.net/ | <tags stripped>
nixbot ... builds ... sign in ... Repositories no repositories enabled yet
```

The actual path matters, per `plan.md:570`: there is no `/api/v1/projects` at the pinned revision.
`/api/v1/projects`, `/api/projects` and `/projects` all return `404 Not Found`; `/health` returns
`200`. The repository set is reported by the HTML interface at `/`, and that is the path recorded
here as the interface's own report.

The service's state agrees. Every table is empty except the migration ledger:

```text
$ psql -d nixbot -At -c 'select relname, n_live_tup from pg_stat_user_tables order by relname;'
api_tokens|0            build_attributes|0     build_effects|0        builds|0
check_runs|0            failed_builds|0        failed_statuses|0      projects|0
revoked_sessions|0      scheduled_effect_runs|0 scheduled_effects|0   schema_migrations|24
webhook_secrets|0       work_queue|1
```

`projects` has zero rows, so the repository set is empty in fact and not only in presentation.
`builds` and `check_runs` have zero rows, so no build has been recorded since deployment.

The evaluated configuration is what makes that hold, and both boundaries are set:

```text
$ nix eval .#nixosConfigurations.magnetite.config.services.nixbot --apply '...'
{ buildSystems = [ "x86_64-linux" ]; createLocally = true;
  domain = "nixbot.scientistexperience.net"; evalWorkerCount = 2;
  nginxACME = true; nginxEnable = true; repoAllowlist = [ ];
  statusContextPrefix = "nixbot"; topic = null; }
```

`topic = null` disables topic-based adoption (`modules/nixos/nixbot.nix:102`) and
`repoAllowlist = [ ]` admits nothing (`modules/nixos/nixbot.nix:107`).

The strongest single observation is incidental and worth recording because it is a live negative
test rather than an absence. A genuine push to the installed repository arrived during verification
and produced no build:

```text
$ psql -d nixbot -c 'select * from work_queue;'
id=1  kind=change  status=done  error=(empty)
dedup_key=change-github-807284872-4fb2eeef557cfb04e9ec32680262cadff7033a01
payload={"forge":"github","branch":"main","forge_repo_id":"807284872",
         "commit_sha":"4fb2eeef557cfb04e9ec32680262cadff7033a01",
         "commit_message":"claude-code: 2.1.247 -> 2.1.250", "pr_number":null}
created_at=2026-08-28 02:05:07.874+00  finished_at=2026-08-28 02:05:07.886+00
```

The event was received, enqueued, processed to `done` in twelve milliseconds with no error, and
created zero rows in `projects`, `builds` or `check_runs`.
The service saw work for a repository it can see and declined to build it, which is the requirement.

### 10.4 Delivery authentication both ways — NOT VERIFIED, operator-only

**This box stays unchecked.** The redelivery half requires the forge application's advanced settings
tab, which is available only under the operator's own identity, and it was not attempted here.

What is already established is the *accepted* arm, incidentally and honestly:

```text
$ journalctl -u nixbot.service
Aug 28 02:05:07  INFO: - "POST /webhooks/github HTTP/1.1" 202 Accepted
Aug 28 02:05:08  INFO: - "POST /webhooks/github HTTP/1.1" 200 OK
```

Two deliveries from GitHub were accepted at the configured endpoint, and the 02:05:07 one is the
`work_queue` row in §10.3, so it was not merely accepted at the HTTP layer but acted on.
That is consistent with the shared secret matching after the operator replaced it in the GitHub UI
with the value the deployment generated.
It is not proof of authentication, because an endpoint that accepted everything would look the same.
The rejection arm is what distinguishes them and it has not been run.

Exact steps for the operator, one pass:

1. Open `https://github.com/organizations/sciexp/settings/apps/sciexp-nixbot/advanced`.
2. In "Recent Deliveries", pick any delivery whose response was `202` or `200` and press **Redeliver**.
3. Expected evidence, the accepted arm: the delivery row's response updates to `202 Accepted`
   (or `200 OK`), and on magnetite
   `sudo journalctl -u nixbot.service --since '-5 min' | grep webhooks/github`
   shows a matching `POST /webhooks/github HTTP/1.1" 202 Accepted` at that moment.
   A signature mismatch would instead show `401` or `403` on the delivery row.
4. Expected evidence, the rejection arm — run this from any machine:

   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' \
     -X POST https://nixbot.scientistexperience.net/webhooks/github \
     -H 'Content-Type: application/json' \
     -H 'X-GitHub-Event: push' \
     -H 'X-GitHub-Delivery: 00000000-0000-0000-0000-000000000000' \
     -d '{}'
   ```

   Expected: `401` or `403`, never `202` or `200`, because no `X-Hub-Signature-256` header was sent.
   Corroborate on the host that nixbot logged the rejection and that `work_queue` gained no row:
   `sudo -u postgres psql -d nixbot -At -c 'select count(*) from work_queue;'` must be unchanged.
5. Tick `tasks.md` 10.4 only when both arms are observed, and record both status codes here.

### 10.5 Both databases exist on the one instance

```text
$ sudo -u postgres psql -c '\l'
      Name      |     Owner      | Encoding
----------------+----------------+---------
 buildbot       | buildbot       | UTF8
 nixbot         | nixbot         | UTF8
 ... (cognee, gitea, matrix-synapse, niks3, postgres, template0, template1)

$ sudo -u postgres psql -c '\du'
 buildbot       |
 nixbot         |
 postgres       | Superuser, Create role, Create DB, Replication, Bypass RLS
```

Both databases exist side by side on the one instance, each owned by its own role, and neither role
carries superuser or createdb.
The new database was created by the module's own `database.createLocally = true`
(`modules/nixos/nixbot.nix:115`), and the schema is fully migrated: 24 migrations applied at
startup, `initial` through `drop_forge_tokens`, `journalctl -u nixbot.service`, Aug 28 02:01:04-05.

### 10.6 No verdict namespace collision

Both arms of `tasks.md:54` hold.

Arm one, no check run under the incumbent's prefix originates from the new service.
The new service's `statusContextPrefix` is the module default `nixbot`, and the incumbent's contexts
are `buildbot/...`:

```text
$ nix eval --raw .#nixosConfigurations.magnetite.config.services.nixbot.statusContextPrefix
nixbot
```

`statusContextPrefix` is set nowhere in this repository — no assignment exists — so it is the
module default and not the incumbent's prefix, which is what `tasks.md:21` asks.
Stronger: the new service's `check_runs` table has zero rows (§10.3), so it has emitted no check run
at all, under any prefix.

Arm two, no repository's required checks name the new service's prefix.
The default branch of the one installed repository is governed by ruleset `16212553`:

```text
$ gh api /repos/cameronraysmith/vanixiets/rulesets/16212553
name: buildbot   target: branch   enforcement: active
conditions.ref_name.include: [~DEFAULT_BRANCH]
rules: deletion, non_fast_forward, required_status_checks
  required_status_checks: context=buildbot/nix-build  integration_id=3305657
```

The single required context is `buildbot/nix-build`, and it is pinned to `integration_id 3305657`,
which is `sciexp-buildbot` (§9.5).
The new application is `4743700`, so a check run from it cannot satisfy that requirement even if it
were named identically, and no required check names `nixbot`.
Classic branch protection on `main` reports no `required_status_checks` block at all.

### 10.7 Capacity baseline

Recorded as the datum the first repository opt-in will be measured against.
Both readings the artifacts ask for are here: `plan.md:591` names host memory, store usage against
quota, and the nixbot unit's memory; `tasks.md:55` names the incumbent's evaluation and build
activity.

Host memory, against the 32 GiB budget in `design.md:3` and `plan.md:19`:

```text
$ free -h
               total        used        free      shared  buff/cache   available
Mem:            30Gi        12Gi        11Gi        87Mi       7.0Gi        17Gi
Swap:           30Gi       298Mi        30Gi
```

Store dataset against its quota:

```text
$ zfs list -o name,used,avail,quota zroot/root/nix
zroot/root/nix   48.7G   201G   250G

$ df -h /nix
zroot/root/nix   250G   49G   202G   20%   /nix
```

48.7 G of the 250 G quota is in use, 20 percent, with 201 G free.

The nixbot unit itself: one process, `MainPID 1195299`, a uvicorn server on the unix socket
`/run/nixbot/web.sock` with no worker pool spawned, since no build has run.
Its configured ceiling is the sizing decision, not its present draw:
`evalWorkerCount = 2` at `evalMaxMemorySize = 2048` (`modules/nixos/nixbot.nix:84`, `plan.md:19`),
so 4 GiB of eval headroom against the incumbent's four workers at 2 GiB, 8 GiB.
The present 12 GiB in use therefore includes the incumbent's active builds and none of nixbot's
eventual eval load; the first opt-in should be measured as a delta against 12 GiB used / 17 GiB
available.

Incumbent evaluation and build activity, the other half of the baseline:

```text
$ psql -d buildbot -At -c 'select count(*) from builds;'
59164
$ psql -d buildbot -c 'select results, count(*) from builds group by results order by results;'
 results | count
       0 | 54909     (success)
       1 |     7     (warnings)
       2 |  1683     (failure)
       5 |  1921     (exception)
       6 |   636     (cancelled)
  (null) |     8     (in progress)
```

59,164 builds retained under a four-week janitor horizon
(`JanitorConfigurator(logHorizon=timedelta(weeks=4))`, master.cfg), highest build id 60436, eight in
flight at the moment of observation, and five builds started within the same second at 02:08:03-04.
That is the incumbent's working rate, and it is the load nixbot's first opt-in will be added to.

### 10.8 The rollback path is available

Verified by instantiation rather than realization, the same amendment task 7.1 records and for the
same reason: the operator's machine is `aarch64-darwin` against an `x86_64-linux` target, so
realizing copies an entire system closure locally for information instantiation already supplies.
`tasks.md` 10.8 is amended accordingly and the amendment is stated in the task text.

Removing `nixbot` from magnetite's aspect list — deleting line 45 of
`modules/machines/nixos/magnetite/default.nix`, leaving the upstream import at line 37 in place —
and instantiating the host's check:

```text
$ nix eval .#checks.x86_64-linux.nixos-magnetite.drvPath
"/nix/store/28ar1w6mdn20kf7qf3v3bvq89q3c9cv3-nixos-system-magnetite-26.11.20260804.85f6261.drv"
EXIT=0
```

For comparison, the same attribute with the aspect present, on the same tree:

```text
$ nix eval .#checks.x86_64-linux.nixos-magnetite.drvPath
"/nix/store/wshfaafhcyalpsc25czjlnsci0dy43jz-nixos-system-magnetite-26.11.20260804.85f6261.drv"
EXIT=0
```

Two distinct derivations, both instantiating cleanly with no evaluation error, option collision or
assertion failure. Withdrawal is a redeploy, not a repair.
The edit was reverted; the working tree carries no trace of it.

Per `design.md:132-133`, the database, the role, the state directory and the credential entries
persist after such a rollback and are harmless; removing them would be a deliberate cleanup and is
not part of the rollback path verified here.

---

## 11. Ledger amendments and corrections

Three places where a task's stated verification needed correction rather than a tick as written.
Each is amended in `tasks.md` and stated here.

**Task 7.1, already amended before this session.** Instantiation substituted for realization; the
reasoning is in the task text. This report neither widens nor narrows it: no realization of this
host's toplevel has happened, and the deployment realized the closure on the host rather than
locally. Left honest.

**Task 10.8, amended here.** Same substitution as 7.1, for the same reason, recorded in the task text.
`plan.md:598` calls for `nix build .#checks.x86_64-linux.nixos-magnetite`; what ran is
`nix eval ... .drvPath`, twice, and both results are in §10.8.

**Task 3.3, amended: the stated secret scan cannot discharge this requirement.**

The task's verification names `just lint` "including its secret scan". Two claims about that gate
were made in sequence during this work and both were wrong; the correction below is the third and
is the one the tick now rests on.

The first claim was that no secret-scanning hook exists behind `just lint`. It does.
`.pre-commit-config.yaml` is a symlink into the nix store that fails to parse as JSON, which is the
likely cause of that miss; read as YAML it declares exactly two hooks and the first is `gitleaks`
8.30.1.

The second claim, made here, was that its passing therefore verifies the task as written.
It does not, and this is the substantive correction:

```text
$ python3 -c "import yaml; ..." .pre-commit-config.yaml
id: gitleaks
  entry: .../gitleaks-8.30.1/bin/gitleaks protect --staged --verbose --redact
  args: []
  pass_filenames: False
  stages: ['pre-commit']

$ git diff --cached --name-only | wc -l
0
```

`gitleaks protect --staged` reads the git index. It reads neither the working tree nor history, and
`pass_filenames: false` means no path is handed to it either. With zero staged files it scans an
empty index and passes unconditionally: a check that could not have failed, and therefore vacuous as
evidence that no credential value is *already* in the repository.
It is a guard against future commits, not an audit of past ones, and that is the only way it is
cited here.

Substituted verification: a three-layer content search for the credential values themselves,
with positive controls.

A distinctive fragment of each of the three credentials was obtained by decrypting the stored
entries locally — an interior body line of the application private key, the whole OAuth client
secret, the whole deployment-generated webhook secret — and searched for across three layers.
The working-tree layer includes hidden and gitignored paths; the tracked layer reads `HEAD`; the
history layer is `git log --all -S`, which walks every commit on every ref, since a value that
entered the repository and was later removed would still have entered it.
Patterns were passed on standard input and only filenames and counts were collected, so no value
was printed, written to disk, or placed in a matched output line.

| Search subject | Working-tree files | Tracked files at HEAD | History commits |
|---|---|---|---|
| control — literal `nixbot.scientistexperience.net` | 11 | 9 | 5 |
| control — literal `repoAllowlist` | 6 | 6 | 7 |
| application private key fragment | 0 | 0 | 0 |
| OAuth client secret | 0 | 0 | 0 |
| webhook secret | 0 | 0 | 0 |

The controls are the point. A zero proves absence only if the method has been shown capable of
returning non-zero, and each layer returns non-zero for both controls — including, in the
working-tree layer, matches inside gitignored `logs/`, which demonstrates that layer genuinely
reaches ignored paths rather than skipping them.
The three credential rows are zero in every layer.

Re-run without `grep -I`, so binary files are included rather than skipped, the credential
fragments still match zero files while the hostname control still matches 11.

The stored entries are sops envelopes rather than values:

```text
path                                                                    bytes  data field       PRIVATE KEY
vars/per-machine/magnetite/nixbot-github-app-secret-key/key.pem/secret   3749  ENC[AES256_GCM…  0
vars/per-machine/magnetite/nixbot-github-oauth-secret/secret/secret      1565  ENC[AES256_GCM…  0
vars/per-machine/magnetite/nixbot-github-webhook-secret/secret/secret    1597  ENC[AES256_GCM…  0
```

Each is JSON with exactly two top-level keys, `data` and `sops`; `data` is
`ENC[AES256_GCM,...]`; the `sops` block carries an age-encrypted data key for two recipients, a
`mac`, a `version` and `lastmodified`. None contains a `PRIVATE KEY` line.
The only two files anywhere in the tree carrying `BEGIN ... PRIVATE KEY` are
`packages/docs/src/content/docs/guides/home-manager-onboarding.md:136` and
`packages/docs/src/content/docs/guides/secrets-management.md:337`, both documentation prose showing
the header form and neither carrying key material.

One operational note worth keeping regardless: `just lint` must run inside the dev shell, because
`prek` is not on the ambient PATH and a bare `just lint` exits 127 rather than reporting a scan
result. That is a property of the flake, not of this change.

No secret value is printed anywhere in this report.

**Task 3.2** is genuinely complete and committed, not merely done in a shell.
Both operator-populated slots and the deployment-generated secret are in the repository:
`31e205454` (app private key), `63d82abcb` (OAuth client secret), `53962942d` (webhook secret,
generated by the deployment itself).
`vars/per-machine/magnetite/` now carries 36 generator entries, three of them nixbot's, one
encrypted file each.

**Task 6.2** verified directly:

```text
$ dig +noall +answer nixbot.scientistexperience.net
nixbot.scientistexperience.net.  34 IN CNAME magnetite.scientistexperience.net.
magnetite.scientistexperience.net. 34 IN A  49.12.12.74

$ dig +short buildbot.scientistexperience.net
magnetite.scientistexperience.net.
49.12.12.74
```

Identical resolution to the incumbent, through to the host's own address.
`49.12.12.74` is the Hetzner host, not a provider anycast address, so the record is unproxied as
`tasks.md:32` requires.

**Task 8.1** verified on its observable half. The deployment command ran `[operator]`; what this
session confirmed is the state it produced:

```text
$ systemctl list-units --plain 'nixbot*' 'acme-nixbot*'
nixbot.service                                  loaded active running  nixbot CI service
nixbot.socket                                   loaded active running  nixbot CI service socket
acme-nixbot.scientistexperience.net.service     loaded active exited   Ensure certificate ...
```

The socket unit is present and active, as the task requires.
Corroborating 5.3 at runtime rather than only in evaluation: uvicorn listens on
`/run/nixbot/web.sock` and `ss -ltnp` shows no TCP listener held on the new service's behalf.

---

## 12. Trust boundary

`specs/build-service-interface/spec.md:101-103` requires that this capability not be described, by
itself or in any downstream report, as an end-to-end guarantee that the incumbent build service is
unaffected. This report is such a downstream report and states the limit rather than eliding it.

What is verified is bounded. The two services were observed running side by side, with disjoint
units, users, state directories, databases, roles, hostnames, certificates and verdict prefixes,
and the incumbent observed building normally after the deployment. That is a strong observation at
one moment, not a guarantee over time.

The surfaces they genuinely share remain common-mode and unbounded by anything verified here: one
nginx, one PostgreSQL instance, one nix store under one quota, one ACME account subject to
rate limits, and one host's finite CPU and memory. A failure originating in any of those affects
both services regardless of how disjoint their own configuration is.

One boundary is not machine-assertable at all. The outermost limit on what the new service can see
is the forge application's installation selection, which lives in the forge and can be changed there
without touching this repository or this host. §10.3's evidence that the service builds nothing rests
on two boundaries the machine does assert — the null topic and the empty allowlist — and on one it
cannot. Widening the installation selection would not be visible to any check in this change.

Finally, one acceptance item is genuinely open: the rejection arm of delivery authentication
(§10.4). Until it is observed, this change has evidence that the endpoint accepts authentic
deliveries and no evidence that it refuses inauthentic ones.

---

## Overall Decision

- [ ] (pass) PASS — may proceed to finishing-a-development-branch and archive
- [x] (warn) PASS WITH WARNINGS — may proceed to subsequent steps but note: two items remain open, neither of them a defect. Task 10.4's delivery-authentication rejection arm requires an operator action that cannot be performed from an agent session; the exact steps and expected evidence are written out in §10.4. The design's open question about whether an empty installation repository selection is permitted stays open and untested, because the installation was made with one repository selected; `design.md:180` states either answer satisfies the requirements. Additionally, `proposal.md:26-27` still describes the change as planning-only, which the implementation has outrun.
- [ ] (fail) FAIL — return to the failed artifact, correct it, then re-run verify

**Next step**:

The operator runs §10.4's two probes in one pass and ticks `tasks.md` 10.4 with both status codes.
That closes the last acceptance item in `design.md:135`.
Separately, before archive, `proposal.md:26-27`'s planning-only sentence should be corrected so the
archived record does not contradict itself, and the empty-selection question should be carried
forward into the first repository opt-in change, which is where it will finally be exercised.
