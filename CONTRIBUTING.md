# Team workflow

## Source of work
The [GitHub Project board](https://github.com/users/hyenalouise/projects/3) is the source of truth for project status.
Each GitHub Issue must define:
- expected outcome
- prerequisites
- acceptance evidence
- owner
- reviewer
- affected documentation

Do not maintain a separate backlog document.

Before starting an issue:

1. Confirm its prerequisites are complete.
2. Assign yourself.
3. Move it to **In Progress**.
4. Create a branch using the issue number.
5. Keep design discussions and decisions in the issue comments.

## Review pairs

| Owner | GitHub account | Primary reviewer |
|---|---|---|
| Ina | `@hyenalouise` | Crystal (`@bnnpddnftw`) |
| Crystal | `@bnnpddnftw` | Gab (`@gabstorres`) |
| Gab | `@gabstorres` | Bri (`@lustrousiana`) |
| Bri | `@lustrousiana` | Haze (`@hazellecvs`) |
| Haze | `@hazellecvs` | Ina (`@hyenalouise`) |

Reviewing your assigned partner’s pull request is part of your project responsibility.

When opening a pull request:

1. Mention the assigned reviewer.
2. Link the issue using `Closes #<issue-number>`.
3. Include validation evidence.
4. Do not merge without the required approval.
5. If the assigned reviewer is unavailable, ask the group to assign another reviewer.

## Start a work item

Assign one owner and a different reviewer. Name branches `<type>/issue-<number>-<short-description>`, such as `setup/issue-7-repo-scaffold`, `profile/issue-10-taxi-source`, or `test/issue-31-may-rerun`.

From your local clone or Databricks Git folder:

```sh
git switch main
git pull --ff-only
git switch -c docs/source-profile
```

Edit, validate, inspect the diff, and stage only the intended paths:

```sh
git diff
git add docs/source_profile.md
git commit -m "Document taxi source profile"
git push -u origin docs/source-profile
```

Open a pull request, attach relevant validation evidence, request review, and merge after review. Sync main before starting another task. Avoid simultaneous editing of a shared notebook. Each teammate should have their own Git folder/branch and isolated development output namespace.

One integration owner runs the approved code against the shared demonstration tables. Confirm catalog/schema privileges before defining namespaces. Do not allow parallel development jobs to overwrite shared control state or Gold tables.

## Review expectations

- Explain the problem, behavior, evidence, and remaining uncertainty.
- Check grain, source field names, join cardinality, incremental scope, and rerun behavior.
- Use fully qualified `catalog.schema.table` references; resolve actual names through approved configuration.
- Critical DQ failures stop dependent layers. Record warnings with an owner and rationale.
- Update the relevant canonical documents with the same change.
- Never substitute identical row counts for a content-level idempotency proof.

Require a teammate review by team agreement; configure GitHub enforcement if available for the chosen account/repository plan. Everyone contributes code or documentation with meaningful commits. Do not commit secrets or downloaded source data.
