---
title: Research axis kanidm-source
status: working-note
date: 2026-09-06
---

# Research axis: Kanidm OIDC provider source

Axis: the Rust source of `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1`, read directly to settle the `email_verified` question that `research/kanidm-oidc-claims.md` left open from documentation alone.
`cameronraysmith/kanidm` is our fork of `kanidm/kanidm`, and the revision `ed10baa494adc1549c2e9e3d750465cc1052a7d1` is upstream tag `v1.11.0`, which is the version the deployed server runs (`research/kanidm-oidc-claims.md` section 1).
Purpose: settle plan Q2, ground the `sub`, `preferred_username`, `name`, and issuer forms that the earlier artifact could only infer, and record the refresh-token facts relevant to plan Q15.
Terms follow the charter designation table in `docs/notes/development/omnigent/charter.md`.

## Scope and method

The Omnigent-side findings of `research/kanidm-oidc-claims.md` section 4 stand and are not repeated here.
The files read in the fork are `server/lib/src/idm/oauth2.rs`, `server/lib/src/idm/account.rs`, `server/lib/src/valueset/address.rs`, `server/lib/src/valueset/mod.rs`, `server/lib/src/value.rs`, `server/lib/src/entry.rs`, `server/lib/src/server/mod.rs`, `server/lib/src/constants/mod.rs`, `server/core/src/https/oauth2.rs`, `proto/src/oauth2.rs`, `proto/src/constants.rs`, `proto/src/constants/uri.rs`, `proto/src/attribute.rs`, `server/lib/src/migration_data/dl15/access.rs`, `server/lib/src/migration_data/dl15/groups.rs`, `server/lib/src/migration_data/dl15/mod.rs`, `tools/cli/src/opt/kanidm.rs`, `Cargo.toml`, and `Cargo.lock`.
The claim struct Kanidm serialises is `OidcClaims` from the external crate `compact_jwt`, which the workspace pins as `compact_jwt = "^0.5.6"` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:Cargo.toml:187`) and the lockfile resolves to `version = "0.5.6"` from crates.io (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:Cargo.lock:987-989`).
That crate's source is read from `github:kanidm/compact-jwt` at commit `95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e`, the commit that sets `version = "0.5.6"` in its `Cargo.toml`; the only later commit before `0.5.7` changes `src/oidc.rs` at lines 311 and after 361 only, so lines 1-260 holding the struct definitions are identical in both candidates for the published `0.5.6`.
No `AGENTS.md` of any repository under the `kanidm` organisation or of the fork was opened, and the fork's working tree differs from `ed10baa494adc1549c2e9e3d750465cc1052a7d1` only by deleting that file (`git diff --stat` prints `AGENTS.md | 10 ----------`).
Line numbers cite the fork's files at `ed10baa494adc1549c2e9e3d750465cc1052a7d1`.

## 1. How Kanidm builds the standard claims

One function, `s_claims_for_account(o2rs, account, scopes)`, builds the standard claims for both the `id_token` and the userinfo response (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3340-3380`).
Its body is:

```rust
    let preferred_username = if o2rs.prefer_short_username {
        Some(account.name().into())
    } else {
        Some(account.spn().into())
    };

    let (email, email_verified) = if scopes.contains(OAUTH2_SCOPE_EMAIL) {
        if let Some(mp) = &account.mail_primary {
            (Some(mp.clone()), Some(true))
        } else {
            (None, None)
        }
    } else {
        (None, None)
    };

    let updated_at: Option<OffsetDateTime> = if scopes.contains(OAUTH2_SCOPE_PROFILE) {
        account
            .updated_at
            .as_ref()
            .map(OffsetDateTime::from)
            .and_then(|odt| odt.replace_nanosecond(0).ok())
    } else {
        None
    };
    OidcClaims {
        // Map from displayname
        name: Some(account.displayname.clone()),
        scopes: scopes.iter().cloned().collect(),
        preferred_username,
        email,
        email_verified,
        updated_at,
        ..Default::default()
    }
```

(`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3345-3379`).

### `email_verified`

`email_verified` is the constant `Some(true)` whenever the granted scopes contain `email` and the account has a primary mail address, and it is `None` otherwise (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3351-3359`).
No other code path assigns the field; `rg -n 'email_verified' server/lib/src/idm/oauth2.rs` matches only line 2613 (a consent-screen PII label), line 3351 (the destructuring above), and line 3376 (the struct literal above).
The field's type is `Option<bool>` with `#[serde(skip_serializing_if = "Option::is_none")]`, so the JSON either carries `"email_verified": true` or omits the key; the value `false` is never emitted (`github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e:src/oidc.rs:70-72`).
`OAUTH2_SCOPE_EMAIL` is `ATTR_EMAIL`, whose value is the string `email` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:118`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:259`).
The value is not derived from any verification state on the account; the only attribute name containing "verif" in the schema enum is `IdVerificationEcKey`, which is unrelated to mail (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/attribute.rs:89`), and the boolean is unconditional once a primary mail exists.
Omnigent's `_claim_is_verified_true` accepts boolean `True` (`research/kanidm-oidc-claims.md` section 4), so the default `OMNIGENT_OIDC_EMAIL_CLAIM=email` path passes without `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` for any account that has a mail address.

### `email` and the primary mail

`email` is `account.mail_primary`, cloned (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3352-3353`).
`Account::mail_primary` is populated from `get_ava_mail_primary(Attribute::Mail)` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/account.rs:129-131`), which calls `to_email_address_primary_str()` on the `mail` value set (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/entry.rs:2891-2894`).
That method returns `None` when the set is empty and otherwise the set's `primary` string (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/valueset/address.rs:562-568`).
When a `mail` attribute arrives over the HTTP API, each value is parsed by `Value::new_email_address_s`, which sets the primary flag to `false` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/server/mod.rs:770`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/value.rs:1879-1885`).
The value set is then created from the first value with `ValueSetEmailAddress::new(a)`, which makes that value the primary (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/valueset/mod.rs:891`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/valueset/address.rs:262-266`), and later values change the primary only when flagged or when the set was empty (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/valueset/address.rs:366-374`).
This is the mechanism behind the nixpkgs option text "First given address is considered the primary address" (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:566-571`).
An account with no `mail` attribute yields `email: None` and `email_verified: None`, so both keys are absent and Omnigent rejects the login with `Rejecting id_token: 'email' claim is missing or not a non-empty string` (`research/kanidm-oidc-claims.md` section 4); the operational precondition is one mail address on the person record, not a verification step.

### `sub`

`sub` in the `id_token` is `OidcSubject::U(session_ctx.account_uuid)`, the account UUID (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2044`).
`OidcSubject` is `#[serde(untagged)]` with variants `U(Uuid)` and `S(String)`, so the UUID serialises as its hyphenated string (`github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e:src/oidc.rs:35-43`).
The unit test asserts `oidc.sub == OidcSubject::U(UUID_TESTPERSON_1)` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5785`).
`sub` is therefore not the SPN and does not change with `prefer_short_username`.

### `preferred_username`

`preferred_username` is always present and is `account.name()` when the client's `prefer_short_username` is true, otherwise `account.spn()` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3345-3349`).
`Account::name()` returns the `name` attribute or falls back to the SPN (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/account.rs:297-299`), and `spn()` returns the `spn` attribute (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/account.rs:293-295`).
The tests show the two forms: `Some("testperson1@example.com")` with the default and `Some("testperson1")` after enabling the short-username setting (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5803-5806`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5965-5968`).
The emission does not depend on the `profile` scope.
`prefer_short_username` is read from the client entry's `oauth2_prefer_short_username` attribute with default `false` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:951-953`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:178`), which is the attribute `kanidm-provision` writes from the nixpkgs `preferShortUsername` option (`github:oddlama/kanidm-provision@139c2762e77e10cb2327d76f2f8d99e91e4cb07b:src/main.rs:250`; `github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:662-666`).

### `name`, `updated_at`, and `scopes`

`name` is always `Some(account.displayname.clone())` regardless of scope (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3372`), and `displayname` is the required `displayname` attribute of the account (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/account.rs:104-107`).
`updated_at` is emitted only when the granted scopes contain `profile`, truncated to whole seconds (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3361-3369`).
No `family_name`, `given_name`, `nickname`, `picture`, `locale`, or other `profile` claim is set, because the struct literal leaves them at `..Default::default()` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3378`); the book's list of profile claims names the OIDC standard set, not what Kanidm fills.
A non-standard `scopes` array carrying the granted scopes is emitted whenever it is non-empty (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3373`; `github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e:src/oidc.rs:58-60`).

### `groups` and claim maps

Group and claim-map claims are built by `extra_claims_for_account` and land in the flattened `claims` map beside the standard claims (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3382-3471`; `github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e:src/oidc.rs:239-243`).
Claim-map values are inserted first and the scope-derived claims second "so that a user can't stomp our claim names" (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3419-3420`).
The `groups` scope implies both UUID and SPN per group, `groups_uuid`, `groups_spn`, and `groups_name` select one form each, and the claim key is always `groups` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3433-3466`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:261-264`).
The `ssh_publickeys` scope adds an `ssh_publickeys` array (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3422-3431`).
Omnigent reads none of these (`research/kanidm-oidc-claims.md` section 4), so they matter only if a future consumer is added.

### Which scopes reach the claim builder

`process_requested_scopes_for_identity` denies the authorisation with `AccessDenied` unless every requested scope is in the union of the scope maps for groups the identity belongs to, and the granted set is the requested set plus every supplementary-scope-map entry for those groups (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3487-3514`).
An `id_token` is generated only when the granted scopes contain `openid` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2016`).
For a client whose only scope map is `omnigent_users = [ "openid" "profile" "email" ]` and a consumer requesting `openid email profile`, the granted set is exactly those three, so the token carries `sub`, `name`, `preferred_username`, `email`, `email_verified`, `updated_at`, and `scopes`, and nothing else beyond the JWT registered claims.

## 2. id_token versus userinfo

The `id_token` is built in `generate_access_token_response` from `s_claims_for_account` and `extra_claims_for_account` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2039-2058`).
The userinfo response is built in `oauth2_openid_userinfo` from the same two functions, using the scopes stored in the access token (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3045-3066`).
Both return an `OidcToken` with `sub: OidcSubject::U(<account uuid>)`, `aud` equal to the client id, `azp` equal to the client id, and `jti` equal to the OAuth2 session id (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2042-2058`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3050-3066`).
The unit test asserts `oidc.s_claims == userinfo.s_claims` and `userinfo.claims.is_empty()` for the same session (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5838-5839`).
The `id_token` registered claims are `iss`, `sub`, `aud`, `iat`, `nbf = iat`, `exp = iat + 900`, `auth_time` when the session has one, `nonce`, `azp`, and `jti`, with `at_hash`, `acr`, and `amr` left `None` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2042-2058`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5786-5798`).
`auth_time` comes from `ident.last_verified_at()` at authorisation time (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2472`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1443`), which is the claim Omnigent's optional `reauth=1` path requires (`research/kanidm-oidc-claims.md` section 4).
The userinfo route accepts both `GET` and `POST` at `/oauth2/openid/{client_id}/userinfo` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/core/src/https/oauth2.rs:787-792`).
Claim emission therefore does not differ between the two surfaces, and the curl probe's userinfo step is redundant with its `id_token` step.

## 3. Client-level configuration and its effect on claims

The client fields at the nixpkgs pin are `public`, `displayName`, `originUrl`, `originLanding`, `basicSecretFile`, `imageFile`, `enableLocalhostRedirects`, `enableLegacyCrypto`, `allowInsecureClientDisablePkce`, `preferShortUsername`, `scopeMaps`, `supplementaryScopeMaps`, and `claimMaps` (`github:NixOS/nixpkgs@85f62611fa3f3eacbcfe3bc7a6d6518b443ca442:nixos/modules/services/security/kanidm.nix:592-722`).
Of these, only `preferShortUsername`, `scopeMaps`, `supplementaryScopeMaps`, and `claimMaps` reach the claim builder: the first selects the `preferred_username` form (section 1), the next two determine the granted scope set (section 1), and the last populates `o2rs.claim_map` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1022`).
`enableLegacyCrypto` maps to `oauth2_jwt_legacy_crypto_enable` and selects `SignatureAlgo::Rs256` instead of `Es256` for both the `id_token` and the access token; it does not alter any claim (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:918-941`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2068-2071`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:177`).
`allowInsecureClientDisablePkce` maps to `oauth2_allow_insecure_client_disable_pkce`, which is negated into `enable_pkce` for a `Basic` client, while a `Public` client always requires PKCE (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:733-736`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:572-577`); it does not alter any claim.
Consent-screen labelling is the only other place scopes touch PII: when `openid` is requested and `email` is granted, the consent token lists `email` and `email_verified` as the PII to be disclosed (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2608-2615`).
The D4 client, copied from synapse with defaults for every crypto and PKCE flag, therefore emits exactly the claim set stated at the end of section 1.

## 4. Issuer, discovery document, and endpoint paths

Per client, Kanidm derives every URL from the server origin at resource-server load time: `iss` is the origin with path `/oauth2/openid/{client_id}`, `authorization_endpoint` has path `/ui/oauth2`, `token_endpoint` has path `OAUTH2_TOKEN_ENDPOINT`, `userinfo_endpoint` has path `/oauth2/openid/{client_id}/userinfo`, and `jwks_uri` has path `/oauth2/openid/{client_id}/public_key.jwk` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:961-980`).
`OAUTH2_TOKEN_ENDPOINT` is `/oauth2/token` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants/uri.rs:18`).
The `iss` field is a `Url` set with `set_path(&format!("/oauth2/openid/{client_id}"))`, so it carries the client path and no trailing slash; the test asserts `discovery.issuer == Url::parse("https://idm.example.com/oauth2/openid/test_resource_server")` and `oidc.iss` equal to the same URL (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:979-980`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5558-5562`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:5780-5784`).
The origin on `magnetite` is `origin = "https://${domain}"` with `domain = "accounts.scientistexperience.net"` (`github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:46`; `github:cameronraysmith/vanixiets@590f75195cc7acbb3926d39397bf860c2c6efc65:modules/nixos/kanidm.nix:130`), so for the `omnigent` client `iss` is exactly `https://accounts.scientistexperience.net/oauth2/openid/omnigent`, and `OMNIGENT_OIDC_ISSUER` must be that string, confirming `research/kanidm-oidc-claims.md` F3 from the issuer side.
The discovery document is served at `/oauth2/openid/{client_id}/.well-known/openid-configuration` and, as an alias, at `/.well-known/openid-configuration/oauth2/openid/{client_id}` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/core/src/https/oauth2.rs:769-780`).
Its body sets `response_types_supported: [code]`, `response_modes_supported: [query, fragment]`, `grant_types_supported: [authorization_code, urn:ietf:params:oauth:grant-type:token-exchange]`, `subject_types_supported: [public]`, `id_token_signing_alg_values_supported` to `[ES256]` or `[RS256]` by `sign_alg`, `token_endpoint_auth_methods_supported: [client_secret_basic, client_secret_post]`, `claims_supported: None`, and `code_challenge_methods_supported: [S256]` when PKCE is required (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3149-3178`).
`scopes_supported` is the union of every scope map and supplementary scope map on the client (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:982-987`), which is why the deployed synapse document lists exactly `email`, `openid`, and `profile`.
`claims_supported` is hard-coded `None` with the comment `// What claims can we offer?` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3170-3171`), which is why the discovery document could not settle Q2.
The token endpoint accepts client authentication either from the HTTP Basic header or from `client_id` and `client_secret` form fields, in that order of preference (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:676-687`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/oauth2.rs:324-329`), and a `Basic` client's secret is compared in constant time (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1226-1235`), so Omnigent's POST-body authentication is accepted and the first-login observation named in `research/kanidm-oidc-claims.md` F2 is no longer needed to establish it.

## 5. Refresh tokens and lifetimes

Every authorisation-code exchange returns `refresh_token: Some(...)` beside the access token and `id_token` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:2181-2189`).
The refresh grant is `GrantTypeReq::RefreshToken { refresh_token, scope }` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/oauth2.rs:165-169`), dispatched to `check_oauth2_token_refresh` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1272-1275`), which rejects expired tokens, validates the session, destroys the session on refresh-token reuse, and re-issues through `generate_access_token_response` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1603-1743`).
The discovery `grant_types_supported` does not advertise `refresh_token`, because the `GrantType` enum has only `AuthorisationCode`, `Implicit`, and `TokenExchange` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/oauth2.rs:505-513`), so the grant is supported but unadvertised.
Access tokens and `id_token`s expire after `OAUTH2_ACCESS_TOKEN_EXPIRY = 15 * 60` seconds, with the comment that access-token expiry "can not" be configured (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/constants/mod.rs:189-191`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:1990-1994`).
Refresh tokens expire after the client's `oauth2_refresh_token_expiry` attribute or the default `OAUTH_REFRESH_TOKEN_EXPIRY = 3600 * 16` seconds (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:957-959`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/constants/mod.rs:186-187`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:proto/src/constants.rs:179`).
Neither the nixpkgs module nor `kanidm-provision` v1.3.0 sets that attribute; `rg -n 'refresh'` over the module returns nothing at the pin and the provisioner writes only `oauth2_rs_origin`, `oauth2_rs_origin_landing`, `oauth2_allow_insecure_client_disable_pkce`, `oauth2_jwt_legacy_crypto_enable`, `oauth2_prefer_short_username`, and the three map attributes (`github:oddlama/kanidm-provision@139c2762e77e10cb2327d76f2f8d99e91e4cb07b:src/main.rs:210-286`).
None of this bears on Omnigent's 8-hour session, because Omnigent mints its own session cookie with `ttl_hours=config.session_ttl_hours` immediately after validating the `id_token` (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:418-423`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/oidc.py:280`) and never stores or uses the IdP `refresh_token`; the only `refresh_token` values in `routes/auth.py` are Omnigent-issued CLI login grants (`github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:435-441`; `github:omnigent-ai/omnigent@381bf638fb31e6a51990d9dab54ea9ef4b933711:omnigent/server/routes/auth.py:637-647`).
The 15-minute `id_token` expiry is irrelevant for the same reason: Omnigent validates `exp` once at the callback, seconds after issuance.
Plan Q15's recommended `OMNIGENT_OIDC_SESSION_TTL_HOURS` default of 8 therefore stands without a Kanidm-side dependency.

## 6. Consequences for D4 and Q2

Q2 is answered statically: with `scopeMaps.omnigent_users = [ "openid" "profile" "email" ]` and Omnigent's default scopes `openid email profile`, every account that has at least one `mail` address receives `"email": "<primary mail>"` and `"email_verified": true`, and `OMNIGENT_OIDC_SKIP_EMAIL_VERIFICATION` stays unset.
The failure mode is an account without a `mail` address, which yields no `email` key at all and is rejected by Omnigent before `email_verified` is consulted; the fix is `mailAddresses` on the person record or `kanidm person update <name> --mail <addr>`, not the waiver.
`sub` is the account UUID and `preferred_username` is the account `name` under `preferShortUsername = true`, which matters only if `OMNIGENT_OIDC_EMAIL_CLAIM` is ever changed from `email`; the earlier artifact's warning that a bare `name` fails the domain allowlist stands.
The trust argument for `email_verified` is that Kanidm asserts `true` for any stored primary mail without a verification step, so the claim vouches for the operator-managed `mail` attribute, not for a verified mailbox; this is the same trust the waiver would express, obtained without disabling Omnigent's check.
Plan Q2's text and D4's sentence "the only unverified Kanidm behaviour is the `email_verified` claim" can be updated to cite this artifact; the D4 configuration itself needs no change.
The claim vouches for an operator-set address only if ordinary people cannot write their own `mail`, and the built-in access controls at the tag's target domain level 15 (`DOMAIN_TGT_LEVEL = DOMAIN_LEVEL_1_11`, `DOMAIN_LEVEL_1_11: DomainVersion = 15`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/constants/mod.rs:82`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/constants/mod.rs:92`) satisfy that condition.
`idm_acp_self_write`, whose receiver is `idm_all_persons`, lists credentials, keys, and passwords in `modify_present_attrs` and not `Attribute::Mail` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/access.rs:968-1000`), and `idm_acp_self_name_write` grants only `Name`, `DisplayName`, and `LegalName` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/access.rs:1003-1031`).
Self-write of `mail` exists only through `idm_acp_people_self_write_mail`, whose receiver is the group `idm_people_self_mail_write` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/access.rs:908-926`), and that built-in group is created with `members: Vec::with_capacity(0)` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/groups.rs:325-332`).
Otherwise `mail` on a person is written by `idm_people_admins` through `idm_acp_people_pii_manage` (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/access.rs:1352-1379`), and all of these profiles are in the domain level 15 access list (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/mod.rs:270`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/mod.rs:281`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/migration_data/dl15/mod.rs:307`).
So `email_verified: true` from this deployment means an administrator set the address, provided `idm_people_self_mail_write` stays empty and the deployed domain has migrated to level 15; the deployed level is operational state this axis did not observe.

## Conclusion

`email_verified` is settled: Kanidm 1.11.0 emits the constant boolean `true` whenever the granted scopes include `email` and the account has a primary mail address, and omits the key otherwise (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/idm/oauth2.rs:3351-3359`; `github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e:src/oidc.rs:70-72`).
No runtime check is needed for the claim's value; the residual runtime check that stays useful is confirming that the operator's person record carries a `mail` address before the first login, and the existing probe's step 3 does that by printing the decoded `id_token` payload:

```sh
TOK=$(curl -sS -u "omnigent:${SECRET}" -d grant_type=authorization_code -d "code=<CODE>" \
  -d redirect_uri=https://omni.scientistexperience.net/auth/callback -d "code_verifier=${CV}" \
  https://accounts.scientistexperience.net/oauth2/token)
printf '%s' "$TOK" | python3 -c 'import sys,json,base64; t=json.load(sys.stdin); p=t["id_token"].split(".")[1]; print(json.dumps(json.loads(base64.urlsafe_b64decode(p+"="*(-len(p)%4))),indent=2))'
```

The expected output for an account with a mail address contains `"email": "<primary mail>"`, `"email_verified": true`, `"sub": "<account uuid>"`, `"preferred_username": "<name>"`, and `"name": "<displayname>"`; a payload without `email` means the account lacks a `mail` attribute.
The cheaper equivalent that needs no token exchange is `kanidm person get <name>` on `magnetite`, checking for a `mail` line.

## Flags

- F1 This artifact and the rewritten `research/kanidm-oidc-claims.md` now cover the same ground (claim builder, `sub`, `preferred_username`, issuer, discovery, client options, mail access control) with overlapping citations; the material unique to this artifact is the refresh-token flow and lifetimes (section 5), the id_token-versus-userinfo comparison (section 2), and the attribute-enum search showing no mail-verification attribute.
- F2 The `compact_jwt` citation uses `github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e`, the commit that sets `version = "0.5.6"`; the crates.io `0.5.6` tarball may have been cut from that commit or from `b3ace1537726be7f77296ca26b3efc29778f200a`, and the cited struct lines are byte-identical at both, but the repository has no `v0.5.6` tag to make the mapping exact.
- F3 Kanidm's discovery document omits `refresh_token` from `grant_types_supported` while the token endpoint honours the grant; this is a Kanidm inconsistency with no effect on Omnigent, recorded in case a future consumer relies on discovery to decide whether to refresh.

## Additional sources acquired

- `github:kanidm/compact-jwt@95a3eb9cbc9e9c3272a18ed243ee75d08c291f4e` (the commit setting `version = "0.5.6"`, the version `Cargo.lock` pins), read from a clone already present under the `ghq` root when this axis started; this axis did not clone it, read only `Cargo.toml` and `src/oidc.rs` from it, and opened no `AGENTS.md`.

## Questions

- Q-A Given F1, should this artifact stay a standalone research axis, or should its unique sections (2 and 5) be folded into the rewritten `research/kanidm-oidc-claims.md` and this file deleted?
Recommended: keep it standalone for now and let the synthesis step cite whichever is more specific, since neither file is on `main` yet and a merge is cheap later.
- Q-D Should the plan's D4 record `idm_people_self_mail_write` staying empty as the operational invariant behind `email_verified: true` (section 6), and should the post-deployment list include `kanidm group list-members idm_people_self_mail_write` to confirm it?
Recommended: yes to the D4 sentence, and yes to the one-line check since it is read-only.
- Q-E Does the operator want the probe in the conclusion kept in the plan's post-deployment list now that its purpose narrows to confirming a `mail` address, or replaced by `kanidm person get <name>`?
Recommended: replace, and keep the token-exchange probe only as a diagnostic for a failed first login.
- Q-F Section 6's access-control conclusion assumes the deployed domain has migrated to level 15; should the plan's pre-deployment checks include reading the domain level on `magnetite` with `kanidm system domain show`, which prints the domain entry whose `version` attribute holds the level (`github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:tools/cli/src/opt/kanidm.rs:1501-1506`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:tools/cli/src/opt/kanidm.rs:1267-1269`; `github:cameronraysmith/kanidm@ed10baa494adc1549c2e9e3d750465cc1052a7d1:server/lib/src/server/mod.rs:2531-2532`), to confirm it?
Recommended: yes, as one read-only line, since the ACP set differs across levels and the deployed instance's level is operational state no static source records.
