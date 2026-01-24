# Branching & Release Strategy

Sono uses a multi-branch strategy to manage stable, beta, and nightly releases.

## Branches

### `main` - Stable Releases
Production-ready code for end users.
- **Versions**: `v1.0.0`, `v1.1.0`, `v2.0.0`
- **Quality**: Thoroughly tested, stable

### `beta` - Beta Testing
Release candidates for public testing.
- **Versions**: `v1.0.0-beta.1`, `v1.1.0-beta.2`
- **Quality**: Feature-complete, may have minor bugs

### `nightly` - Development
Latest development code and features.
- **Versions**: `nightly-20260111`
- **Quality**: May be unstable, for testing only

## Contributing

### Development Flow

```
feature/xyz → nightly → beta → main
```

1. **Create a feature branch** from `nightly`
   ```bash
   git checkout nightly
   git pull
   git checkout -b feature/my-feature
   ```

2. **Make your changes** and commit
   ```bash
   git add .
   git commit -m "feat: add my feature"
   ```

3. **Submit a PR to `nightly`**
   - All PRs should target `nightly` unless it's a hotfix
   - PRs are automatically tested by CI

4. **After merge**, your changes will be included in the next nightly build

### Hotfixes

For urgent production bugs:

```
hotfix/xyz → main → beta → nightly
```

1. Create hotfix branch from `main`
2. Submit PR to `main`
3. After release, backport to `beta` and `nightly`

## Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (v2.0.0): Breaking changes
- **MINOR** (v1.1.0): New features, backward compatible
- **PATCH** (v1.0.1): Bug fixes, backward compatible

## Getting Builds

| Channel | Stability | Updates | Download |
|---------|-----------|---------|----------|
| **Stable** | Production | Manual | [Latest Release](../../releases/latest) |
| **Beta** | Testing | Pre-release | [Beta Releases](../../releases?q=beta) |
| **Nightly** | Bleeding edge | On-demand* | [Nightly Builds](../../releases?q=nightly) |

*Nightly builds are created when code is pushed to the `nightly` branch.

---

## FAQ

**Q: Which branch should I contribute to?**
A: Always target `nightly`, unless you're making a hotfix.

**Q: How do I get the latest development build?**
A: Download the latest nightly build from the [Releases](../../releases) page.

**Q: Can I install multiple versions?**
A: No, installing a new version will replace the existing one if it uses the same package name.

**Q: How often are releases made?**
A: Stable and Beta releases are made manually. Nightly builds are created every day at 2 a.m. UTC.

---

For maintainers: See `.github/workflows/` for CI/CD configuration.
