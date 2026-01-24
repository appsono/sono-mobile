# Contributing to Sono

Thank you for your interest in contributing to Sono! We welcome contributions from the community.

## Table of Contents

- [Contributing to Sono](#contributing-to-sono)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
  - [How Can I Contribute?](#how-can-i-contribute)
    - [Reporting Bugs](#reporting-bugs)
    - [Suggesting Features](#suggesting-features)
    - [Code Contributions](#code-contributions)
  - [Development Setup](#development-setup)
  - [Pull Request Process](#pull-request-process)
    - [PR Checklist](#pr-checklist)
  - [Coding Guidelines](#coding-guidelines)
    - [Dart/Flutter Style](#dartflutter-style)
    - [Code Organization](#code-organization)
    - [Naming Conventions](#naming-conventions)
    - [Comments](#comments)
    - [Error Handling](#error-handling)
    - [State Management](#state-management)
    - [Performance](#performance)
  - [Commit Message Guidelines](#commit-message-guidelines)
    - [Types](#types)
    - [Examples](#examples)
  - [Testing](#testing)
    - [Manual Testing](#manual-testing)
    - [What to Test](#what-to-test)
  - [Getting Help](#getting-help)
  - [Recognition](#recognition)
  - [License](#license)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Environment details** (device, Android version, app version)
- **Logs** if available (from logcat or crash reports)

### Suggesting Features

Feature suggestions are welcome! Please:

- Use a clear and descriptive title
- Provide a detailed description of the proposed feature
- Explain why this feature would be useful
- Include mockups or examples if applicable

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit your changes (see [Commit Guidelines](#commit-message-guidelines))
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

1. **Prerequisites**
   - Flutter SDK 3.7.0+
   - Android Studio or VS Code (or other Code Editor that supports Dart)
   - Git

2. **Clone and setup**
   ```bash
   git clone https://github.com/appsono/sono-mobile.git
   cd sono-mobile
   flutter pub get
   ```

3. **Environment configuration**
   ```bash
   cp .env.template .env
   # Edit .env with your configuration
   ```

4. **Firebase setup**
   - Create a Firebase project
   - Download `google-services.json`
   - Place it in `android/app/`
   - Update `.env` with Firebase config

5. **Run the app**
   ```bash
   flutter run
   ```

## Pull Request Process

1. **Update documentation** - Update README.md if you change functionality
2. **Test your changes** - Ensure the app builds and runs without errors
3. **Follow coding guidelines** - See below
4. **Update CHANGELOG** - Add a brief description of your changes
5. **One feature per PR** - Keep pull requests focused on a single feature or fix
6. **Link issues** - Reference related issues in your PR description

### PR Checklist

- [ ] Code follows the project's coding guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No new warnings introduced
- [ ] Tested on a physical device or emulator
- [ ] Screenshots included (for UI changes)

## Coding Guidelines

### Dart/Flutter Style

- Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide
- Use `flutter analyze` to check for issues
- Run `flutter format .` before committing
- Maximum line length: 120 characters

### Code Organization

```dart
//1. Imports - group by: dart, flutter, packages, local
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

import '../services/api_service.dart';
import '../widgets/player.dart';

//2. Class definition
class MyWidget extends StatelessWidget {
  //3. Final fields
  final String title;

  //4. Constructor
  const MyWidget({super.key, required this.title});

  //5. Override methods
  @override
  Widget build(BuildContext context) {
    //Implementation
  }

  //6. Private methods
  void _handleTap() {
    //Implementation
  }
}
```

### Naming Conventions

- **Classes**: `PascalCase` (e.g., `AudioPlayerService`)
- **Files**: `snake_case` (e.g., `audio_player_service.dart`)
- **Variables/Functions**: `camelCase` (e.g., `playNextSong`)
- **Constants**: `lowerCamelCase` (e.g., `const maxRetries = 3`)
- **Private members**: Prefix with `_` (e.g., `_privateMethod`)

### Comments

- Use `///` for documentation comments
- Use `//` for implementation comments
- Add TODO comments with issue numbers: `//TODO(#123): Description`

```dart
///Plays the next song in the queue.
///
///Returns `true` if a song was played, `false` if the queue is empty.
Future<bool> playNext() async {
  //Check if queue has items before proceeding
  if (_queue.isEmpty) {
    return false;
  }

  // TODO(#456): Add crossfade support
  await _player.play(_queue.removeAt(0));
  return true;
}
```

### Error Handling

- Use try-catch blocks for async operations
- Log errors appropriately
- Show user-friendly error messages

```dart
try {
  await apiService.login(username, password);
} on NetworkException catch (e) {
  logger.error('Network error during login', e);
  showErrorSnackbar('Network error. Please check your connection.');
} catch (e) {
  logger.error('Unexpected error during login', e);
  showErrorSnackbar('An unexpected error occurred.');
}
```

### State Management

- Use Provider for state management
- Keep business logic in services
- Keep UI widgets focused on presentation

### Performance

- Avoid rebuilding widgets unnecessarily
- Use `const` constructors where possible
- Dispose of resources (controllers, streams, etc.)
- Use `ListView.builder` for long lists

## Commit Message Guidelines

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, no code change)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Build process or auxiliary tool changes

### Examples

```
feat(player): add crossfade support

Implemented crossfade between tracks with configurable duration.
Users can now enable crossfade in settings.

Closes #123
```

```
fix(auth): resolve token refresh issue

Fixed a bug where refresh tokens weren't being stored correctly,
causing users to be logged out unexpectedly.

Fixes #456
```

## Testing

### Manual Testing

- Test on multiple Android versions
- Test with different screen sizes
- Test edge cases (no internet, empty library, etc.)
- Test performance with large music libraries

### What to Test

- [ ] App builds successfully
- [ ] No crashes during normal use
- [ ] UI looks correct on different screen sizes
- [ ] Features work as expected
- [ ] No regression in existing features
- [ ] Error handling works properly

## Getting Help

- **Questions**: Open a [Discussion](https://github.com/appsono/sono-mobile/discussions)
- **Chat**: [Join our community](https://discord.sono.wtf)
- **Email**: business@mail.sono.wtf

## Recognition

Contributors will be recognized in:
- The README.md contributors section
- Release notes for significant contributions
- The app's credits page

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Sono!