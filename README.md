# Radius Labs

Hands-on labs for [Radius](https://radapp.io) — the open-source application platform for cloud-native apps.

## Lab Catalog

| Lab | Description |
|-----|-------------|
| [001 – Customer Support Agent](./001-customer-support-agent/README.md) | AI-powered customer support agent with Radius Recipes for Azure and AWS |
| [002 – Order Management Console](./002-order-console/README.md) | Microservices order-processing app with Dapr and Radius, deployable to Kubernetes or Kubernetes + Azure |

## Bicep extension migration

Both labs use `br:ghcr.io/radius-project/bicep-types-radius:edge` with `experimentalFeaturesEnabled.ociEnabled` enabled. The development `latest`/`edge` references move to GHCR `edge`; the checked-in local custom extensions remain unchanged. In particular, `radiusData` in lab 001 provides `Radius.Data/postgreSqlDatabases`, not a legacy built-in Radius alias. Neither lab currently consumes the AWS extension (`br:ghcr.io/radius-project/bicep-types-aws`).

This migration must remain draft until these pre-merge gates are met:

- The publishing prerequisites are complete and the canonical GHCR artifacts and selected `edge` tag are publicly available. The Radius publishing work also depends on the immutable upstream Bicep release; do not substitute a branch build.
- Use a compatible **released** Radius CLI and its matching Bicep compiler. Radius [v0.61.1](https://github.com/radius-project/radius/releases/tag/v0.61.1) uses Bicep 0.46.1; an older installed CLI is not evidence of compatibility.
- From a clean cache without registry credentials, restore and compile every lab Bicep file with that compiler, including the local custom extensions. Resolve any compatibility errors before merging; compilation does not require a cloud deployment.

Anonymous GHCR access returned HTTP 403 when this migration was prepared. Live restore/compilation is therefore blocked, not verified. After publication, run from the repository root in a clean, unauthenticated environment:

```bash
rad version
bicep --version
git ls-files '*.bicep' | while IFS= read -r template; do
  bicep build "$template" --stdout > /dev/null || exit 1
done
```

The build restores the referenced extensions. A successful standalone `bicep restore` invocation is not sufficient evidence that extension restoration works.
