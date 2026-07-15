# Firebase Environments and Services

## 1. Status and Authority

This document is the canonical environment, service, deployment, and operational contract for Crown's Firebase and associated Google Cloud resources. It applies to the Flutter iOS and Android applications, backend deployments, local development, continuous integration, and production release operations.

If another document, checked-in example, local Firebase alias, console setting, or CI workflow conflicts with this specification, this specification controls. Product data and backend behavior remain governed by the other canonical specifications under `docs/Specs/`.

Firebase project IDs are globally unique and therefore cannot be reserved by documentation. The exact IDs in this specification must be verified as available at project-creation time. If either ID is unavailable, project creation must stop and this specification must be amended before a different ID is used. No near-match, numeric suffix, or temporary project may silently become canonical.

This contract does not contain credentials, tokens, private keys, provider secrets, APNs keys, AdMob identifiers, or other secret values. Examples use symbolic names only.

---

# 2. Fixed Environment Matrix

Exactly two persistent Firebase environments exist:

| Environment | Firebase project ID | Firebase display name | Purpose |
| --- | --- | --- | --- |
| Development | `crown-chess-and-checkers-dev` | Crown Development | Developer integration, CI integration tests, internal QA, and non-production release builds |
| Production | `crown-chess-and-checkers` | Crown | Public iOS and Android releases and production backend traffic |

The reverse namespace is `dev.wxlfe.crown`.

| Platform | Development application ID | Production application ID |
| --- | --- | --- |
| iOS bundle ID | `dev.wxlfe.crown.dev` | `dev.wxlfe.crown` |
| Android application ID | `dev.wxlfe.crown.dev` | `dev.wxlfe.crown` |

Each project contains exactly one registered iOS app and one registered Android app for the IDs above. App display names should be `Crown iOS Development`, `Crown Android Development`, `Crown iOS`, and `Crown Android` respectively. A web app must not be registered.

Environment isolation is absolute:

- Development builds connect only to the development Firebase project or to local emulators.
- Production builds connect only to the production Firebase project.
- Production user data must never be copied into development, emulator, test, preview, or analytics environments.
- Development credentials, App Check debug tokens, ad test-device configuration, and test users must never be accepted by production.
- Backend resources must not read across projects.
- There is no shared Firestore database, Auth tenant, FCM registration, Remote Config template, Analytics property, Crashlytics application, App Check registration, task queue, secret version, or deployment identity between environments.

Vercel and web hosting are explicitly excluded. Do not configure Firebase Hosting, Vercel projects, web application registrations, web Analytics streams, or browser deployment workflows for Crown under this contract.

---

# 3. Project Creation and Base Configuration

## 3.1 Creation order

An authorized project owner must perform the following once for each environment:

1. Verify the required project ID is globally available.
2. Create the Firebase project with the fixed project ID and display name.
3. Associate the approved Google Cloud billing account and enable the Blaze plan.
4. Set the default Google Cloud resource location only when prompted by a service and only to the location required by this document.
5. Register the fixed iOS and Android application IDs.
6. Provision the services, identities, budgets, alerts, and integrations defined below.
7. Record immutable generated identifiers, such as Firebase app IDs, project numbers, Analytics measurement identifiers, Workload Identity provider resource names, and AdMob application IDs, in the restricted operations inventory. They are not authored in this specification.

Project creation is not complete until the project ID, project number, display name, billing account, support contact, registered applications, and enabled APIs have been reviewed by a second maintainer.

## 3.2 Location contract

| Resource | Development | Production |
| --- | --- | --- |
| Firestore edition and mode | Standard edition, Native mode | Standard edition, Native mode |
| Firestore database ID | `(default)` | `(default)` |
| Firestore location | `nam5` | `nam5` |
| Cloud Functions region | `us-central1` | `us-central1` |
| Cloud Tasks queue region | `us-central1` | `us-central1` |

Firestore location is immutable after database creation. Both databases must be created directly as Standard edition, Native mode databases in `nam5`; do not create a Datastore-mode, Enterprise-edition, or differently located database for migration later.

Every deployed function must declare `us-central1` in source or shared deployment configuration. Every task queue and every task target must use `us-central1`. Code must not rely on a mutable CLI default region.

## 3.3 Support identity

Firebase Authentication email templates, user-facing Firebase support fields, and permitted support-contact surfaces use:

```txt
nate@wxlfe.dev
```

This address is a support contact, not an application credential. It must not be granted project access merely because it is the public support address. IAM access is assigned separately to named administrator identities and groups under least privilege.

---

# 4. Flutter Flavors and Firebase Configuration

## 4.1 Flavor contract

The Flutter application exposes exactly these release environments:

| Flutter flavor | Dart environment value | iOS bundle ID | Android application ID | Firebase project |
| --- | --- | --- | --- | --- |
| `development` | `development` | `dev.wxlfe.crown.dev` | `dev.wxlfe.crown.dev` | `crown-chess-and-checkers-dev` |
| `production` | `production` | `dev.wxlfe.crown` | `dev.wxlfe.crown` | `crown-chess-and-checkers` |

The environment is selected at build time, never from a user setting, Remote Config, a Firestore document, or runtime hostname. A production-signed artifact must fail its release build if its application ID, generated Firebase options, Google service configuration, or expected project ID does not match the production row.

Use separate Android product flavors and separate iOS schemes/build configurations. Development may use an application display-name suffix such as `Crown Dev`; production uses `Crown`. Both flavors use separate generated Firebase options and native service configuration files.

Application startup must compare the compiled expected project ID and application ID with the initialized Firebase application options. A mismatch is a fatal configuration error: do not authenticate, open Firestore, register FCM, emit Analytics, or continue to the app shell.

## 4.2 Firebase CLI source of truth

Firebase application registrations and native SDK configuration must be retrieved from Firebase using the latest Firebase CLI, not copied from another developer, another flavor, a console download of unknown age, or the production application.

Authenticate with an authorized human identity for local retrieval, then resolve and record the current Firebase app IDs:

```sh
npx -y firebase-tools@latest apps:list --project crown-chess-and-checkers-dev
npx -y firebase-tools@latest apps:list --project crown-chess-and-checkers
```

Retrieve each native configuration using the app ID returned for that exact project and platform:

```sh
npx -y firebase-tools@latest apps:sdkconfig IOS FIREBASE_IOS_APP_ID --project FIREBASE_PROJECT_ID
npx -y firebase-tools@latest apps:sdkconfig ANDROID FIREBASE_ANDROID_APP_ID --project FIREBASE_PROJECT_ID
```

`FIREBASE_IOS_APP_ID`, `FIREBASE_ANDROID_APP_ID`, and `FIREBASE_PROJECT_ID` above are command placeholders, not environment variable names mandated for the application. Retrieval output must be written to the flavor-specific locations expected by the iOS and Android build systems without manually changing project IDs, app IDs, client IDs, API keys, sender IDs, bundle IDs, or package names.

Run the latest supported FlutterFire configuration tool separately for each flavor to generate flavor-specific Dart options from the registered apps. Pin the resulting generated files and the Flutter Firebase package versions in the repository; do not depend on a globally installed CLI at build time. Before accepting regeneration, review the diff and verify the embedded project ID, app ID, bundle ID or package name, storage bucket, and messaging sender ID against the selected Firebase app registration.

Generated Firebase client configuration contains identifiers used by the client SDK and is not an administrative credential. It may be checked in when required by the native build, but it must still be environment-correct and code-reviewed. Secret values must never be placed in generated Dart options, `GoogleService-Info.plist`, `google-services.json`, Dart defines, source control, build logs, or application assets.

## 4.3 Local Firebase aliases

The repository Firebase configuration uses these aliases:

```txt
dev  -> crown-chess-and-checkers-dev
prod -> crown-chess-and-checkers
```

Deployment commands and CI workflows must always provide an explicit project ID or reviewed alias. A bare deploy that depends on the operator's current Firebase project is prohibited. Production deployment must additionally assert that the resolved project ID is `crown-chess-and-checkers` before any change is applied.

---

# 5. Required Services

## 5.1 Service inventory

Both Firebase projects require the following application services:

| Service | Development policy | Production policy |
| --- | --- | --- |
| Firebase Authentication | Test and internal accounts; provider configuration isolated from production | Public account authority |
| Cloud Firestore | Standard, Native, `(default)`, `nam5` | Standard, Native, `(default)`, `nam5` |
| Cloud Functions for Firebase | Second generation in `us-central1` unless a documented incompatibility requires otherwise | Second generation in `us-central1` unless a documented incompatibility requires otherwise |
| Cloud Tasks | Queues and targets in `us-central1` | Queues and targets in `us-central1` |
| Firebase Cloud Messaging | Development APNs and Android application credentials | Production APNs and Android application credentials |
| Firebase Remote Config | Development template and conditions | Independently promoted production template |
| Google Analytics for Firebase | Crown Development property | Crown Production property |
| Firebase Crashlytics | Integrated for both native apps; collection disabled until optional-data consent | Integrated for both native apps; collection disabled until optional-data consent; release symbol upload required |
| Firebase Performance Monitoring | Integrated for both native apps; collection disabled until optional-data consent; debug diagnostics only when deliberately requested | Integrated for both native apps; collection disabled until optional-data consent; no verbose diagnostic mode |
| Firebase App Check | Debug providers only for approved development/emulator builds | Enforced production attestation providers |
| Google AdMob | Test ads only | Live ads only in public builds; test ads for test devices and pre-release verification |

Required Google Cloud APIs include the APIs used by Firebase management, Firestore, Cloud Functions, Cloud Run, Artifact Registry, Cloud Build, Eventarc, Pub/Sub where used, Cloud Tasks, Secret Manager, IAM Credentials, Security Token Service, and service usage. APIs must be enabled because a defined service or deployment path needs them, not speculatively.

## 5.2 Authentication

Configure Sign in with Apple, Google, and email/password independently in both projects. Anonymous authentication is disabled. Authorized domains must contain only domains required by native provider flows and Firebase defaults that cannot safely be removed; do not add Vercel, preview, or unrelated domains.

Provider client IDs, Apple keys, Apple team configuration, and provider secrets are environment-scoped wherever the provider permits. Secrets are stored only in the provider console, Firebase supported configuration, or Secret Manager as appropriate. Authentication templates identify the correct Crown environment during development and use `nate@wxlfe.dev` as the support contact.

Security Rules and backend authorization must enforce the identity and verification requirements in `docs/Specs/Auth Account and Offline.md`. Console provider enablement is not an authorization boundary.

## 5.3 Firestore

Rules, indexes, and field overrides are source-controlled and deployed together through reviewed workflows. Rules default to deny. Production console edits to rules or indexes are emergency actions and must be reconciled back to source immediately after the incident.

Automatic backups, point-in-time recovery, TTL policies, and deletion protection must be configured according to launch retention and recovery policy before public release. Enabling a TTL policy does not replace authorization or application-level expiry checks. Development may use shorter retention for disposable fixtures but must preserve the same schema, Rules, indexes, and transaction behavior.

## 5.4 Functions and Tasks

Functions run with dedicated least-privilege runtime service accounts rather than default broad project identities. Deployment identities and runtime identities are distinct. Function ingress, callable authentication, App Check enforcement, concurrency, timeout, memory, minimum instances, maximum instances, retry policy, and secret bindings must be explicit in source or reviewed infrastructure configuration.

Cloud Tasks queues are provisioned explicitly in `us-central1`. Queue rate, concurrency, retry, backoff, and attempt limits must be finite and selected per workload. Task handlers authenticate requests using a dedicated OIDC-calling service account and validate the expected audience and caller. Public unauthenticated task handlers are prohibited. Payloads contain stable identifiers and revisions, not credentials or unnecessary personal data.

The task name or application idempotency key must make retried delivery safe. Dead or exhausted tasks must produce an alert and sufficient redacted diagnostics for recovery. Deleting a queue is not a normal deployment step.

## 5.5 Firebase Cloud Messaging

FCM registrations are scoped to the current Firebase project, application, installation, and signed-in UID. Development tokens must never be written to production and production tokens must never be used from development. Sign-out and account switching follow the token cleanup contract in `docs/Specs/Auth Account and Offline.md`.

APNs authentication material and other messaging credentials are maintained in restricted provider/Firebase configuration and rotated without entering source control. Notification payloads contain no private game state, email address, OAuth data, or secret. The backend treats delivery as best effort; notifications do not replace authoritative Firestore or callable state.

## 5.6 Analytics

Create exactly two GA4 properties:

| Firebase project | GA4 property | Reporting time zone | Currency | Data streams |
| --- | --- | --- | --- | --- |
| `crown-chess-and-checkers-dev` | Crown Development | `America/New_York` | USD | One iOS stream and one Android stream |
| `crown-chess-and-checkers` | Crown Production | `America/New_York` | USD | One iOS stream and one Android stream |

No web stream is permitted. Do not link either property to BigQuery. Development and production data must remain in their respective properties. Analytics consent, retention, advertising features, user properties, event parameters, and data collection must satisfy the approved privacy and platform policies before public launch.

Analytics event parameters and user properties must not receive email addresses, names, Crown handles, FCM tokens, Firebase ID tokens, UIDs, free-form user text, exact private match payloads, or secret values. After optional-data consent and authentication, the current opaque Firebase UID may be used only in GA4's dedicated User-ID field as defined by [[Analytics Measurement Plan]]. Use documented low-cardinality event schemas. DebugView and analytics debug mode are allowed only for development builds or explicitly designated production test devices and must not be enabled in public artifacts.

## 5.7 Crashlytics and Performance Monitoring

Crashlytics and Performance Monitoring are integrated for both registered native apps, but collection defaults to disabled and follows the single device-scoped optional-data choice in [[Analytics Measurement Plan]]. Development and production reports remain separated by Firebase app registration.

Release builds must upload Android mapping files and iOS dSYM files from the exact shipped artifact. CI must fail or block release promotion when required symbols are missing. Logs, crash keys, traces, URLs, and custom attributes must be allowlisted and redacted; do not include credentials, emails, handles, raw UIDs, FCM tokens, private match content, or arbitrary server responses.

Performance custom traces and metrics use bounded names and values. Production verbose SDK logging and performance debug instrumentation are disabled.

## 5.8 AdMob

AdMob is configured for the registered iOS and Android applications in each environment. AdMob account ownership, generated application IDs, and production ad-unit IDs are recorded in the restricted operations inventory. AdMob application and ad-unit IDs are identifiers rather than credentials, but they must be injected into the correct native flavor and must never be guessed or shared across platform registrations.

Development builds request only Google's official test ad units or ads served in test mode. Emulators and simulators are test devices. Physical QA devices must be explicitly configured as test devices. Automated tests must use a fake ad boundary and must not request live inventory.

Production public builds use production ad-unit IDs. Internal, pre-release, and store-review testing against a production application registration must still use test-device mode. Clicking live ads for testing, generating artificial impressions, or using production inventory in development is prohibited. Consent and privacy configuration must be complete before requesting an ad where required.

---

# 6. Remote Config Contract

Remote Config may tune operational presentation and bounded, reversible client behavior. It must not redefine the product, trust boundary, or data contract.

## 6.1 Mutable values

Allowed mutable categories include:

- Kill switches for nonessential client entry points when the server remains authoritative.
- Staged rollout percentages and bounded experiment variants.
- Non-authoritative copy keys and promotional presentation.
- Bounded polling, refresh, retry, animation, and cache intervals within code-enforced safe minimums and maximums.
- Whether an optional telemetry event or nonessential diagnostic is sampled.
- Ad presentation suppression or a stricter presentation frequency than the canonical eligibility contract.
- Minimum supported application version messaging, provided store enforcement and backend compatibility do not depend solely on a client flag.

Every parameter must have a typed in-code default, owner, description, allowed range or enum, and failure behavior. The app validates fetched values and falls back to its compiled default when a value is missing, malformed, stale, or outside the allowed boundary. Development templates may change freely for testing; production changes require review, template version history, and a rollback plan.

## 6.2 Immutable values

Remote Config must not control or redefine:

- Firebase project IDs, app IDs, bundle IDs, package names, API origins, regions, database paths, or environment selection.
- Authentication, email-verification, authorization, privacy, App Check, or Security Rules requirements.
- Checkers rules, legal moves, result precedence, clocks, rating formulas, League boundaries, rated-friend limits, replay retention, or any server-authoritative invariant.
- Firestore schemas, API request/response schemas, idempotency keys, migration versions, encryption behavior, retention obligations, or deletion semantics.
- Product prices, purchases, entitlement ownership, legal consent, or policy text whose change requires affirmative review.
- Secrets, credentials, signing material, provider tokens, service-account data, or hidden administrative endpoints.
- A switch that enables production data access from a non-production build.

A value that can grant access, alter a competitive result, weaken privacy, bypass a server check, or make persisted data uninterpretable belongs in versioned code and server policy, not Remote Config.

---

# 7. App Check

## 7.1 Development and local use

Development flavor builds use Firebase App Check debug providers only when connecting to the development project. Each developer or CI job uses a separately registered debug token. Tokens are handled as secrets, never committed, never printed in logs, and revoked when a device, developer, or workflow no longer needs access.

The Emulator Suite does not require a production attestation path. Emulator endpoints are selected only by an explicit local-development switch compiled into or passed to a development build. A production build contains no debug token and no code path that selects emulator hosts.

## 7.2 Production enforcement

Production uses:

- App Attest for supported iOS devices, with DeviceCheck as the documented compatibility fallback where required.
- Play Integrity for Android.

Register the production applications and validate telemetry before enabling enforcement. Enforcement must then be enabled for Firestore, callable and HTTP Functions where supported, and any other supported Crown resource that accepts direct application traffic. Backend handlers still validate Auth, authorization, schema, replay protection, and rate limits; App Check does not replace those controls.

Production never accepts App Check debug tokens in public builds. Temporary enforcement rollback is an incident action requiring an owner, recorded reason, expiry time, monitoring, and restoration. It is not a routine troubleshooting step.

---

# 8. Local Emulator Contract

Use the Firebase Local Emulator Suite for repeatable local development and CI integration tests. The committed emulator configuration must pin ports and include at least:

```txt
Authentication Emulator
Cloud Firestore Emulator
Cloud Functions Emulator
Emulator UI
```

Add the Pub/Sub Emulator when a deployed trigger uses Pub/Sub or scheduled-function behavior is represented through Pub/Sub. Use the Storage Emulator only if Cloud Storage becomes an approved Crown dependency; it is not required by this contract.

The suite has no complete Cloud Tasks emulator. Task-producing code must use an injectable queue boundary. Local and CI tests capture the intended task and invoke the Functions-emulator handler with the same authenticated task envelope, payload validation, retry, and idempotency behavior. Tests against the isolated development project must cover real Cloud Tasks OIDC delivery and queue configuration before release.

FCM, Remote Config, Analytics, Crashlytics, Performance Monitoring, App Check attestation, and AdMob do not have complete local emulation under this contract. Local tests use fakes or disable network emission. Their real integrations are verified in the development Firebase project on designated test devices.

Emulator safety requirements:

- Emulator use is allowed only from development builds and tests.
- Test processes set explicit emulator hosts; they do not change production configuration files.
- Emulator Auth and Firestore data is synthetic and disposable.
- CI starts from an empty or versioned fixture state and exits nonzero on Rules or integration-test failure.
- Emulator export data containing personal or production-derived information must not be committed.
- Any test that requires a non-emulated service targets only the development project and uses uniquely prefixed, automatically cleaned test data.

---

# 9. Secrets and Sensitive Configuration

## 9.1 Classification

Secrets include provider private keys, OAuth client secrets, webhook signing secrets, APNs authentication keys, App Check debug tokens, Workload Identity bootstrap-sensitive values where applicable, and any value that grants authority when disclosed. Firebase client API keys and generated client app identifiers are not administrative secrets, but they remain restricted by application, API, and platform controls and must not be mistaken for authorization.

No actual secret may appear in this document, the public repository, Git history, source maps, application logs, CI logs, test fixtures, issue content, release notes, or downloadable build artifacts.

## 9.2 Storage and access

Backend runtime secrets are stored in Google Cloud Secret Manager in the same project as their consumer. Development and production use separate secrets and separate versions. Functions receive only explicitly declared secret bindings. Secret names may be source-controlled; values may not.

Human access is least privilege, auditable, and limited to maintainers with an operational need. CI obtains short-lived Google credentials through Workload Identity Federation and reads only the secrets required by that job. Rotation must create a new secret version, deploy consumers, verify use, disable the prior version, and then destroy it according to the approved recovery window.

Mobile applications are public clients. A value required to remain secret must not be shipped in iOS or Android code, native resources, Dart defines, obfuscation output, or Remote Config. Place privileged operations behind authenticated backend APIs.

---

# 10. GitHub Actions and Workload Identity Federation

The source repository is public:

```txt
github.com/wxlfe/crown
```

Public repository contents and pull-request workflows are untrusted. No workflow triggered from a fork, unreviewed pull request, issue, comment, or arbitrary ref may receive cloud deployment authority or environment secrets.

Create GitHub environments named `development` and `production`. Create separate Google Cloud Workload Identity pools/providers or equivalently isolated provider conditions and separate deployment service accounts for the two Firebase projects. Trust conditions must bind all of the following:

```txt
repository == wxlfe/crown
repository_owner == wxlfe
environment == development | production
```

The provider must also constrain the expected GitHub issuer and audience. Workflow permissions default to read-only and grant `id-token: write` only to the deployment job that exchanges the GitHub OIDC token. Do not use pull-request head repository, branch text, actor name, or an input parameter as the sole authorization condition.

Environment policy:

| GitHub environment | Google project | Deployment source | Protection |
| --- | --- | --- | --- |
| `development` | `crown-chess-and-checkers-dev` | Reviewed commits from approved repository refs | Environment-scoped identity; no fork access |
| `production` | `crown-chess-and-checkers` | Reviewed, immutable release commit or tag | Required human approval, protected release source, environment-scoped identity |

The production deployment job must build or retrieve an artifact tied to the approved commit, assert the production project and app identifiers, and deploy only reviewed targets. Development and production service accounts cannot impersonate each other and cannot access the other project's secrets or resources.

No long-lived Google service-account key is permitted for local development, GitHub Actions, Firebase deployment, or application runtime. Do not create or upload a service-account JSON key as a GitHub secret. Existing keys discovered during setup must be inventoried, replaced with federation or attached runtime identity, revoked, and deleted after verifying no consumer remains.

Deployment IAM grants only permissions needed for the declared Firebase targets and required underlying Google Cloud services. It must not grant project Owner or Editor. Runtime service accounts cannot deploy, and deployment service accounts do not serve application traffic.

---

# 11. Billing, Budgets, and Quotas

Both projects use the Blaze plan and an approved billing account because Cloud Functions, Cloud Tasks, and production-scale services require billing. Billing enablement is not permission for unbounded use.

Create separate Google Cloud budgets scoped to each project. The project owner must approve and record each dollar amount before billing is enabled; an unapproved placeholder amount must not be deployed. Development and production amounts are independent and must reflect the current test plan, expected load, abuse limits, and notification coverage.

Send actual-spend alerts at 50%, 80%, 100%, and 150%, plus a forecasted-spend alert at 100%, to the maintained operational notification channel and billing administrators. Budgets alert; they do not cap spend or automatically disable the application. Automatic billing disablement is prohibited because it can corrupt workflows and cause an uncontrolled outage.

Before public release, owners must review expected load and explicitly revise the production budget when the approved amount is no longer representative. Changes require a recorded reason; a budget is an alerting baseline, not a promise that production can operate within that amount.

Configure finite function maximum instances, Cloud Tasks dispatch rates, Firestore usage alerts where available, log retention, Artifact Registry cleanup, and abuse/rate limits. Review billing and quota trends weekly during active development and after every release until a stable baseline exists. Unexpected spend, quota exhaustion, cryptomining indicators, or unexplained traffic is an incident.

---

# 12. Deployment and Change Control

Source control owns Functions code, Firestore Rules and indexes, emulator configuration, Remote Config defaults/templates where export is supported, and reviewed infrastructure definitions. Console-only settings must be represented in an operations checklist when no safe declarative interface exists.

Promotion order is:

1. Run static analysis and deterministic tests.
2. Run emulator Rules and backend integration tests from a clean state.
3. Deploy to the development project using GitHub WIF.
4. Run isolated development-project integration tests, including real task delivery and native SDK smoke tests.
5. Review the target diff, configuration, release artifact identifiers, and monitoring state.
6. Obtain production GitHub environment approval.
7. Deploy the approved immutable revision to production using production WIF.
8. Run non-destructive production smoke tests and observe errors, cost, task failures, and rollout health.

Do not deploy production from a developer workstation as a normal path. Emergency manual deployment requires an incident record, explicit project selection, short-lived human credentials, a reviewed diff, and immediate reconciliation through the normal workflow.

Remote Config is promoted by exporting the reviewed development template, removing development-only conditions and values, validating parameter schemas and defaults, and publishing a separately reviewed production template. Firestore data is not promoted between environments. Auth users are not promoted. Secret values are provisioned independently.

---

# 13. Acceptance Criteria

The Firebase environment foundation is accepted only when all of the following are true:

- Both required project IDs were globally verified at creation and the projects have the exact IDs and display names in this specification.
- Billing is enabled, project-scoped budgets and alerts exist, and no project uses an unapproved billing account.
- Each project contains exactly the required iOS and Android registrations with the fixed application IDs and no web app.
- Both `(default)` Firestore databases are Standard edition, Native mode, and immutably located in `nam5`.
- All deployed Functions and Cloud Tasks queues are in `us-central1` and use explicit least-privilege runtime identities.
- Flutter `development` and `production` builds initialize only their expected project and fail closed on a mismatch.
- Native Firebase configuration was retrieved from the matching app registrations using the latest Firebase CLI and reviewed without hand-edited identifiers.
- Auth providers, support contact, FCM credentials, Rules, indexes, Remote Config, Analytics, Crashlytics, Performance Monitoring, App Check, and AdMob are configured independently for both environments.
- GA4 has exactly the Crown Development and Crown Production properties, each with `America/New_York`, USD, one iOS stream, one Android stream, no web stream, and no BigQuery link.
- Development uses only App Check debug providers and test ads; production uses attestation enforcement and prevents test credentials or non-test ad verification traffic from crossing boundaries.
- Emulator tests run against synthetic data and no local path can select production from a production build.
- The public GitHub repository deploys through environment-bound WIF with separate development and production identities, and production requires approval.
- No long-lived service-account key or actual secret exists in source control, GitHub Actions secrets as a JSON key, application assets, generated client configuration, or logs.
- Remote Config parameters conform to the mutable boundary and cannot alter immutable server-authoritative behavior.
- Development-project and production smoke tests produce retained evidence without copying or destructively modifying production user data.

---

# 14. Verification Procedure

Verification must record command output or screenshots with account identifiers, tokens, keys, client secrets, and sensitive resource names redacted. Evidence is attached to the release or operations record and includes the date and verifying maintainer.

## 14.1 Project and application inventory

Using the latest Firebase CLI, authenticate with a short-lived authorized identity and verify both inventories:

```sh
npx -y firebase-tools@latest projects:list
npx -y firebase-tools@latest apps:list --project crown-chess-and-checkers-dev
npx -y firebase-tools@latest apps:list --project crown-chess-and-checkers
```

Confirm display names, project IDs, platform registrations, and application IDs against Sections 2 and 4. Confirm separately in Firebase and Google Cloud that no web app or hosting target exists.

## 14.2 Build identity tests

Build and launch both Flutter flavors on iOS and Android. For each artifact, assert before Firebase use:

```txt
compiled flavor
bundle ID or application ID
Firebase project ID
Firebase app ID
messaging sender ID
expected emulator policy
```

Add a negative automated test that pairs development application metadata with production options, and the inverse, and proves startup fails before network or telemetry activity.

## 14.3 Firestore, Functions, and Tasks

Verify the Firestore edition, mode, database ID, and immutable location through authoritative Firebase or Google Cloud inventory. Deploy Rules and indexes to development, run the complete emulator and development Rules suites, and confirm default-deny cases.

List deployed Functions and task queues through supported Google Cloud inventory and assert every resource location is `us-central1`. Enqueue a uniquely identified development task, verify its OIDC-authenticated handler executes once logically under duplicate delivery, and verify an invalid caller and invalid audience are rejected.

## 14.4 Client service smoke tests

On designated development iOS and Android devices:

1. Complete each configured Auth provider flow with test accounts.
2. Read and perform an authorized write through the expected Firestore Rules boundary.
3. Invoke an App Check-protected callable function.
4. Register, receive, rotate, and remove an FCM token through sign-out.
5. Fetch a typed Remote Config value and prove an invalid value falls back safely.
6. Emit an allowlisted Analytics event and confirm it only in Crown Development.
7. Submit a nonfatal Crashlytics test and verify symbols resolve.
8. Capture an allowlisted Performance trace without personal data.
9. Request only a test ad and verify the test designation.

Production smoke tests are non-destructive and use designated test accounts/devices. They confirm production App Check attestation, project isolation, Analytics routing, symbol availability, and test-device ad behavior without clicking live ads or creating material user data.

## 14.5 Identity and secret audit

Review IAM bindings, Workload Identity provider conditions, GitHub environment protections, workflow permissions, runtime identities, deployment identities, and Secret Manager access. Attempted credential exchange from a fork, pull request, wrong repository, and wrong GitHub environment must fail. Development identity access to production and production identity access to development must fail.

Scan the repository and Git history with the approved secret scanner. Inventory Google service-account keys in both projects and confirm no user-managed long-lived key supports Crown. Verify App Check debug tokens and provider secrets are absent from source, artifacts, and logs.

## 14.6 Console-only review

Two maintainers verify settings that are not fully represented by deployable source:

- Firebase and Google Cloud project display names and support contact.
- Billing account, budgets, thresholds, recipients, and quota alerts.
- Firestore edition, mode, location, recovery, and deletion-protection settings.
- Auth providers, templates, and authorized domains.
- FCM/APNs configuration.
- GA4 property names, time zone, currency, stream count, absence of web streams, and absence of BigQuery links.
- App Check providers, registration, enforcement, and debug-token inventory.
- Crashlytics symbol processing and Performance collection.
- AdMob platform registrations, test-device policy, consent configuration, and environment-specific identifiers.
- GitHub production approval and protected release-source policy.

Any failed criterion blocks production promotion. The owner must correct the setting in the development environment first where applicable, rerun the relevant verification, and retain updated evidence. A verbal exception or an undocumented console setting does not satisfy this contract.
