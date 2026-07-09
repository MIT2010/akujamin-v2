# The Solo-Sustainable Flutter Starter Kit
### Architecture designed to be understood in under 30 minutes, five years from now

> Corrections applied vs. the original brief (see chat message for full reasoning):
> `dartz` → hand-rolled `Result<F,S>` sealed class · `hive` → `hive_ce` · UseCase is optional for trivial CRUD · docs consolidated from 12 files to 4.

> **FVM is enforced, not just documented (ADR-006):** `melos run <anything>` already calls `fvm flutter`/`fvm dart` internally, so it's safe with no prefix — but ad-hoc commands (`flutter run`, a manual `flutter pub get`) still need you to type `fvm flutter ...`/`fvm dart ...` yourself. Right after cloning, run `fvm use <versi> --pin` then `melos run doctor` before anything else. See [README.md](README.md) for setup.

---

## 1. Architecture Philosophy

Three beliefs drive every decision below:

1. **A solo developer's real enemy is not "bad code," it's re-learning your own project.** Every abstraction has to pay rent in reduced re-learning time, or it gets cut, no matter how "enterprise" it looks.
2. **Architecture should be evolutionary, not predictive.** We don't build a plugin system for analytics providers because we might switch someday — we build a *thin interface* because swapping is cheap insurance, not speculative infrastructure. There's a difference: an interface is one file; a plugin system is twenty.
3. **Boring technology, boring structure.** Every package in this kit was chosen because it is still being merged into in 2026, not because it's clever. Cleverness is a liability when you're the only one who has to remember it in 2031.

**The 30-minute test:** if a competent Flutter dev can't open this repo cold and explain where a bug fix for "wrong price on checkout screen" belongs within 30 minutes, the architecture has failed, regardless of how many SOLID principles it name-drops.

---

## 2. Why This Architecture (and why not others)

| Alternative considered | Why rejected for *this* brief |
|---|---|
| Single-app, no monorepo, no packages | Fails the "scale to enterprise without refactor" requirement — moving code into packages later means rewriting every import and re-testing everything at once. Packages from day one cost ~1 extra day of Melos setup and save weeks later. |
| MVVM without Clean Architecture layers | Faster to start, but domain logic leaks into ViewModels within 2–3 features. You'd be doing a bigger rewrite at feature #15 than the extra layer costs at feature #1. |
| Riverpod + no Bloc | Genuinely competitive (see the audit above). Rejected only because of the explicit regulated-industry requirement (fintech/health/gov) where an explicit, replayable event log is a real compliance asset, not a preference. |
| GetX | Rejected outright. As of 2026 it has a documented single-maintainer bottleneck and growing incompatibility with recent Flutter SDKs — the opposite of a 5–10 year bet. |
| Full DDD (aggregates, value objects, domain events, CQRS) | Overkill. "Practical DDD" here means: rich models instead of anemic ones, and a ubiquitous language in naming — not event sourcing for a to-do list. |

---

## 3. Monorepo Structure

```
flutter_starter_kit/
├── apps/
│   └── mobile/                  # the actual shippable app (Android/iOS/Web/Desktop)
├── packages/
│   ├── core/                    # Result, Failure, UseCase, Env, Logger, Connectivity, Extensions
│   ├── design_system/           # tokens, themes, reusable widgets
│   ├── shared/                  # cross-feature glue: router, DI root, app-level services
│   ├── authentication/          # feature package
│   ├── feature_home/
│   ├── feature_profile/
│   └── feature_settings/
├── melos.yaml
├── analysis_options.yaml
└── README.md
```

**Rule for creating a new package (answers "do NOT split unnecessarily"):**
A folder becomes a **package** only when at least one of these is true:
- It will be reused by 2+ features (`design_system`, `core`).
- It needs an independently versioned release boundary (a package you might publish or share across apps later).
- It needs isolated unit tests that shouldn't rebuild the whole app.

Otherwise it stays a **folder inside a feature**. This is why `authentication` is a top-level package (used by routing guards *and* every feature that reads "current user") but something like a one-off "confetti animation on checkout success" stays inside `feature_home/lib/src/widgets/`.

---

## 4. Folder Tree (inside one feature package)

```
feature_home/
├── lib/
│   ├── feature_home.dart                # single public export barrel
│   └── src/
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── home_remote_datasource.dart
│       │   │   └── home_local_datasource.dart
│       │   ├── models/
│       │   │   └── home_item_model.dart      # freezed + json_serializable, extends domain entity
│       │   └── repositories/
│       │       └── home_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── home_item.dart            # freezed, no json, no Flutter import
│       │   ├── repositories/
│       │   │   └── home_repository.dart      # abstract contract
│       │   └── usecases/
│       │       └── get_home_feed_usecase.dart # ONLY if real orchestration exists
│       └── presentation/
│           ├── cubit/
│           │   ├── home_cubit.dart
│           │   └── home_state.dart
│           ├── pages/
│           │   └── home_page.dart
│           └── widgets/
│               └── home_item_card.dart
├── test/
│   ├── data/
│   ├── domain/
│   └── presentation/
└── pubspec.yaml
```

**The dependency rule (Clean Architecture, enforced by import direction only — no lint plugin needed for a solo dev):**
`presentation → domain ← data`. Domain never imports Flutter, Dio, or Hive. This single rule is what keeps business logic testable without a simulator, five years in.

---

## 5. Package Responsibilities

| Package | Owns | Never contains |
|---|---|---|
| `core` | `Result`, `Failure`, `UseCase<T,P>`, `ApiClient`, interceptors, `Logger`, `Env`, `Connectivity`, extensions, validators, formatters | Any UI, any feature-specific model |
| `design_system` | Color/typography/spacing tokens, `AppTheme`, buttons, inputs, cards, dialogs, responsive breakpoints | Business logic, network calls |
| `shared` | `AppRouter` (go_router config), the DI composition root, `FeatureFlags`, `Analytics`/`CrashReporter`/`RemoteConfig` interfaces | Feature-specific screens |
| `authentication` | Login/register/token refresh domain + data + minimal UI, `AuthGuard` | Screens unrelated to identity |
| `feature_*` | One bounded product area | Direct imports from another `feature_*` (features talk through `shared` or `core`, never to each other) |

---

## 6. Dependency Graph

```
                 ┌────────────┐
                 │   apps/mobile   │  (composition root, main.dart)
                 └───────┬────────┘
                         │ depends on all features + shared
        ┌────────────────┼─────────────────┐
        ▼                ▼                 ▼
  feature_home     feature_profile   feature_settings
        │                │                 │
        └────────┬───────┴────────┬────────┘
                  ▼                ▼
           authentication      shared
                  │                │
                  └───────┬────────┘
                           ▼
                  design_system   core
                           │        │
                           └───┬────┘
                          (leaf packages, zero
                           internal dependencies)
```

`core` and `design_system` are leaves — they depend on nothing else in the repo. That's what makes them safe to reuse in your *next* Flutter project by literally copying the two folders.

---

## 7. Layer Responsibilities

- **Presentation** — widgets + Cubit/Bloc. Renders state, dispatches events/calls Cubit methods. Zero business logic, zero direct repository calls except the explicitly-allowed trivial-CRUD shortcut (see §21).
- **Domain** — entities (freezed, pure Dart), repository *contracts* (abstract classes), UseCases for orchestration. This layer defines what the app does, not how.
- **Data** — repository *implementations*, remote/local datasources, DTO models (freezed + json_serializable) that map to domain entities. This layer defines how, and is the only layer allowed to throw exceptions (everything above catches and converts to `Failure`).

---

## 8. Data Flow

```
Widget → Cubit.method() → UseCase (if real logic) → Repository (interface)
   → RepositoryImpl → RemoteDataSource (Dio) / LocalDataSource (Hive/secure storage)
   ← Either<Failure, Model> ← Repository converts Model → Entity
   ← Cubit emits new State ← Widget rebuilds via BlocBuilder
```

Every arrow going *right* can throw or fail; every arrow going *left* is a `Result`. The boundary where exceptions become `Result` is always the repository implementation — that's the one place you need to remember when debugging "why did my UI never show an error."

---

## 9. Authentication Flow

```
App start
  → AuthCubit checks SecureStorage for refresh token
  → valid?  → AuthState.authenticated(user) → router redirects to /home
  → invalid/none → AuthState.unauthenticated() → router redirects to /login

Login screen
  → LoginCubit.submit(email, password)
  → AuthRepository.login() → Dio POST /auth/login
  → success → store access+refresh token in flutter_secure_storage
            → AuthCubit.emit(authenticated)
  → failure → LoginState.error(Failure) → shown inline, never a dialog for form errors

Token refresh (interceptor-level, invisible to features)
  → Dio interceptor catches 401 → pauses queued requests
  → calls /auth/refresh once → replays queued requests → if refresh also fails, force logout
```

---

## 10. API Flow

```
Feature Repository
   → ApiClient.get('/endpoint')          (core package, one Dio instance app-wide)
      → LoggingInterceptor (dev only)
      → AuthInterceptor (attaches Bearer token)
      → RetryInterceptor (idempotent GETs only, exponential backoff, max 3)
      → RefreshTokenInterceptor (on 401)
      → ConnectivityInterceptor (fails fast with NetworkFailure if offline, skips a dead 30s timeout)
   → DioException → mapped to typed Failure (ServerFailure, TimeoutFailure, NetworkFailure...)
   → Either<Failure, Response> returned to repository
```

---

## 11. Offline Flow

```
Repository.getData()
  1. Try RemoteDataSource
     success → write-through to LocalDataSource (cache) → return Right(data)
     failure (network) → fall back to LocalDataSource → return Right(cachedData) tagged isStale:true
     failure (server 4xx/5xx) → return Left(Failure) — don't silently serve stale data on a real server error
  2. Mutations while offline → written to an OfflineQueue (Hive box) with status pending
  3. ConnectivityListener (core) → on reconnect, flushes OfflineQueue FIFO, one item at a time,
     each success removes it from the queue, each failure keeps it and stops the flush (no silent data loss)
```

This shape is decided **now** (repository already returns "stale" metadata, a queue box already exists in `core`) precisely so that turning on offline-first for one feature later needs zero refactor — only new local datasource logic.

---

## 12. Dependency Injection Flow

```
main.dart
  → WidgetsFlutterBinding.ensureInitialized()
  → await configureDependencies(env: Env.current)   // injectable-generated
  → runApp(App())

Generated by injectable:
  @module → external deps (Dio instance, SharedPreferences, Hive boxes)
  @LazySingleton → ApiClient, Logger, repositories
  @Injectable → UseCases, Cubits (factory — fresh instance per screen)
  @Environment('dev'|'staging'|'prod') → swaps AnalyticsService implementation etc.
```

No manual `getIt.registerLazySingleton(...)` calls anywhere in feature code — you annotate a class, run `dart run build_runner build`, done.

---

## 13. Routing Flow

```
GoRouter(
  redirect: (context, state) => AuthGuard.redirect(context, state),  // checks AuthCubit state
  routes: [
    ShellRoute(                       // persistent bottom nav
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', ...),
        GoRoute(path: '/profile', ...),
      ],
    ),
    GoRoute(path: '/login', ...),
    GoRoute(path: '/settings/:section', ...),   // nested + deep-linkable
  ],
  errorBuilder: (_, __) => NotFoundPage(),
)

RoleGuard: wraps redirect logic — checks AuthCubit.state.user.role against route metadata
  (a simple `extra: {'roles': ['admin']}` on GoRoute, checked in the same redirect function —
   no need for a separate guard framework)
```

---

## 14. Feature Template (what `mason make feature` generates)

```
feature_<name>/
  lib/feature_<name>.dart
  lib/src/data/...
  lib/src/domain/...
  lib/src/presentation/...
  test/...
  pubspec.yaml   (pre-wired: core, design_system dependencies)
  melos.yaml entry auto-added
```

One brick, one command, ~15 files, all correctly wired to the DI graph via `@injectable` stubs — this is the entire point of Mason here: not "generate everything," but eliminate the 20 minutes of folder/pubspec/import boilerplate every new feature otherwise costs.

---

## 15. Core Package

```dart
// packages/core/lib/src/result/result.dart
sealed class Result<F, S> {
  const Result();
}

final class Ok<F, S> extends Result<F, S> {
  final S value;
  const Ok(this.value);
}

final class Err<F, S> extends Result<F, S> {
  final F failure;
  const Err(this.failure);
}

extension ResultX<F, S> on Result<F, S> {
  T fold<T>(T Function(F failure) onError, T Function(S value) onSuccess) => switch (this) {
        Ok(value: final v) => onSuccess(v),
        Err(failure: final f) => onError(f),
      };

  bool get isOk => this is Ok<F, S>;
  bool get isErr => this is Err<F, S>;
}
```

```dart
// packages/core/lib/src/error/failure.dart
sealed class Failure {
  final String message;
  const Failure(this.message);
}

final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection');
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Session expired');
}
```

```dart
// packages/core/lib/src/usecase/usecase.dart
abstract class UseCase<Type, Params> {
  Future<Result<Failure, Type>> call(Params params);
}

class NoParams {
  const NoParams();
}
```

```dart
// packages/core/lib/src/network/api_client.dart
@lazySingleton
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Future<Result<Failure, T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  // post/put/delete/multipart follow the same shape.

  Failure _mapDioError(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          const NetworkFailure(),
        DioExceptionType.badResponse when e.response?.statusCode == 401 =>
          const UnauthorizedFailure(),
        DioExceptionType.badResponse => ServerFailure(
            e.response?.data['message'] ?? 'Server error',
            statusCode: e.response?.statusCode,
          ),
        _ => const NetworkFailure(),
      };
}
```

Also included in `core` (kept intentionally thin, not shown in full to avoid bloating this document):
`Env` (compile-time `--dart-define` reader), `AppLogger` (wraps `logger` package with named channels: api/bloc/nav/repo), `ConnectivityService` (wraps `connectivity_plus` + `internet_connection_checker_plus`), `Validator`/`Formatter` extensions, `Pagination<T>` model, `ApiResponse<T>` envelope.

---

## 16. Design System

```dart
// packages/design_system/lib/src/tokens/app_colors.dart
class AppColors {
  const AppColors._();
  static const primary = Color(0xFF2D6CDF);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFD32F2F);
  // dark-mode counterparts kept in AppColorsDark, selected by AppTheme
}

// packages/design_system/lib/src/tokens/app_spacing.dart
class AppSpacing {
  const AppSpacing._();
  static const xs = 4.0, sm = 8.0, md = 16.0, lg = 24.0, xl = 32.0;
}
```

```dart
// packages/design_system/lib/src/theme/app_theme.dart
class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        // dynamic color: wrap MaterialApp with DynamicColorBuilder at app level,
        // fall back to this static scheme when the platform doesn't support it
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
      );
}
```

Responsive layout: a single `Breakpoints` class (`mobile < 600 < tablet < 1024 < desktop`) plus one `AdaptiveLayout` widget that swaps between provided `mobile`/`tablet`/`desktop` builders. No responsive *framework* dependency — this is ~50 lines and every dev can read all of it.

Buttons/inputs/cards/dialogs/bottom sheets: each is one file, wraps a Material 3 widget with the design tokens applied, exposes the same named-parameter API as its Material counterpart so it never feels like a foreign DSL.

---

## 17. Shared Package

Owns things that are cross-cutting but *not* generic enough for `core` (i.e., they know about the app's concept of "user" or "feature," `core` does not):

```dart
// packages/shared/lib/src/router/app_router.dart
@lazySingleton
class AppRouter {
  final AuthCubit authCubit;
  AppRouter(this.authCubit);

  late final router = GoRouter(
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: _redirect,
    routes: _routes,
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final loggedIn = authCubit.state is Authenticated;
    final loggingIn = state.matchedLocation == '/login';
    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/home';
    return null;
  }

  // ...routes defined via feature-exposed route lists, so feature_home
  // contributes its own GoRoute objects instead of shared knowing about home's screens.
}
```

```dart
// packages/shared/lib/src/analytics/analytics_service.dart
abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? params});
  Future<void> setUserId(String? id);
}

// Default no-op so the app runs before you've picked a provider:
@LazySingleton(as: AnalyticsService)
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {}
  @override
  Future<void> setUserId(String? id) async {}
}

// Later: @Environment('prod') class FirebaseAnalyticsService implements AnalyticsService {...}
// Business logic calls `analyticsService.logEvent(...)` and never knows which provider is live.
```

`CrashReporter` and `RemoteConfig` follow the identical no-op-first-interface pattern.

---

## 18. Example Login Feature — the running example for §18–24

Folder: `packages/authentication/`. We'll trace one feature through every layer.

**Domain entity:**
```dart
// domain/entities/user.dart
// NOTE: freezed 3.x requires `abstract class` for single-constructor classes
// (plain `class X with _$X` no longer compiles — see ADR-005).
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String role,
  }) = _User;
}
```

**Domain repository contract:**
```dart
// domain/repositories/auth_repository.dart
abstract class AuthRepository {
  Future<Result<Failure, User>> login({required String email, required String password});
  Future<Result<Failure, void>> logout();
  Future<User?> getCachedUser();
}
```

---

## 19. Example API Integration

```dart
// data/datasources/auth_remote_datasource.dart
@injectable
class AuthRemoteDataSource {
  final ApiClient _client;
  AuthRemoteDataSource(this._client);

  Future<Result<Failure, UserModel>> login(String email, String password) {
    return _client.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      parser: (json) => UserModel.fromJson(json),
    );
  }
}
```

```dart
// data/models/user_model.dart
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();
  const factory UserModel({
    required String id,
    required String email,
    required String role,
    required String accessToken,
    required String refreshToken,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  User toEntity() => User(id: id, email: email, role: role);
}
```

---

## 20. Repository Example

```dart
// data/repositories/auth_repository_impl.dart
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;   // core, wraps flutter_secure_storage

  AuthRepositoryImpl(this._remote, this._tokenStorage);

  @override
  Future<Result<Failure, User>> login({required String email, required String password}) async {
    final result = await _remote.login(email, password);
    return result.fold(
      (failure) => Err(failure),
      (model) async {
        await _tokenStorage.save(access: model.accessToken, refresh: model.refreshToken);
        return Ok(model.toEntity());
      } as S Function(UserModel), // (illustrative — in real code, await before returning)
    );
  }

  @override
  Future<Result<Failure, void>> logout() async {
    await _tokenStorage.clear();
    return const Ok(null);
  }

  @override
  Future<User?> getCachedUser() => _tokenStorage.getCachedUser();
}
```

---

## 21. UseCase Example — and when to skip it

```dart
// domain/usecases/login_usecase.dart
// Justified here: orchestrates repository call + (future) analytics + (future) biometric prompt.
@injectable
class LoginUseCase implements UseCase<User, LoginParams> {
  final AuthRepository _repository;
  final AnalyticsService _analytics;

  LoginUseCase(this._repository, this._analytics);

  @override
  Future<Result<Failure, User>> call(LoginParams params) async {
    final result = await _repository.login(email: params.email, password: params.password);
    if (result.isOk) await _analytics.logEvent('login_success');
    return result;
  }
}

class LoginParams {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});
}
```

**The explicit skip rule:** a feature like "get the app's current build number" or "toggle a boolean preference" does **not** get a UseCase. The Cubit calls the repository directly:
```dart
// Allowed shortcut — no UseCase, because there is no orchestration to name:
class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repository;
  SettingsCubit(this._repository) : super(SettingsInitial());

  Future<void> toggleDarkMode() async {
    final result = await _repository.setDarkMode(!state.isDarkMode);
    result.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (_) => emit(state.copyWith(isDarkMode: !state.isDarkMode)),
    );
  }
}
```
If this Cubit ever grows a second dependency or a business rule ("can't enable analytics opt-out below age 13"), *that's* the signal to promote it to a UseCase — not before.

---

## 22. Bloc Example

```dart
// presentation/cubit/login_state.dart
// NOTE: freezed 3.x requires `sealed class` for union types with multiple
// factory constructors (see ADR-005) — plain `class` no longer compiles here.
@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.initial() = LoginInitial;
  const factory LoginState.loading() = LoginLoading;
  const factory LoginState.success(User user) = LoginSuccess;
  const factory LoginState.failure(Failure failure) = LoginFailureState;
}
```

```dart
// presentation/cubit/login_cubit.dart
@injectable
class LoginCubit extends Cubit<LoginState> {
  final LoginUseCase _loginUseCase;
  LoginCubit(this._loginUseCase) : super(const LoginState.initial());

  Future<void> submit({required String email, required String password}) async {
    emit(const LoginState.loading());
    final result = await _loginUseCase(LoginParams(email: email, password: password));
    result.fold(
      (failure) => emit(LoginState.failure(failure)),
      (user) => emit(LoginState.success(user)),
    );
  }
}
```

---

## 23. UI Example

```dart
// presentation/pages/login_page.dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LoginCubit>(),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: BlocConsumer<LoginCubit, LoginState>(
            // NOTE: freezed 3.x removed .when()/.whenOrNull() in favor of
            // Dart 3's native sealed-class pattern matching (see ADR-005).
            listener: (context, state) {
              switch (state) {
                case LoginSuccess():
                  context.go('/home');
                case LoginFailureState(:final failure):
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(failure.message)));
                case LoginInitial():
                case LoginLoading():
                  break;
              }
            },
            builder: (context, state) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppTextField(label: 'Email', controller: _emailController),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(label: 'Password', obscure: true, controller: _passwordController),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Login',
                  loading: state is LoginLoading,
                  onPressed: () => context.read<LoginCubit>().submit(
                        email: _emailController.text,
                        password: _passwordController.text,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

No `if (state is LoginLoading) CircularProgressIndicator()` scattered logic — `AppButton` (design_system) owns its own loading-spinner-replaces-label behavior, so every screen gets consistent loading UI for free.

---

## 24. Local Cache Example

```dart
// packages/core/lib/src/storage/secure_token_storage.dart
@lazySingleton
class SecureTokenStorage {
  final FlutterSecureStorage _storage;
  SecureTokenStorage(this._storage);

  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<void> clear() => _storage.deleteAll();
}
```

**When to use which local storage — the rule, not just the tool list:**

| Storage | Use for | Never use for |
|---|---|---|
| `flutter_secure_storage` | Tokens, refresh tokens, anything an attacker profits from reading off a rooted device | Large objects (it's slow at scale — encrypted keychain/keystore reads aren't free) |
| `shared_preferences` | Small, non-sensitive flags: theme mode, onboarding-seen, locale | Structured/relational data, anything security-sensitive |
| `hive_ce` (not `hive`) | Structured local cache that needs to survive restarts and be queried (offline feed cache, draft forms) | Secrets (Hive boxes are unencrypted by default; use `HiveAesCipher` only if you must, and still prefer secure_storage for real secrets) |

---

## 25. Feature Flag Example

```dart
// packages/shared/lib/src/flags/feature_flags.dart
abstract class FeatureFlags {
  bool isEnabled(String key);
}

@LazySingleton(as: FeatureFlags)
class LocalFeatureFlags implements FeatureFlags {
  // Backed today by a local JSON asset / compile-time map.
  // Swapping to Firebase Remote Config later means implementing this interface once —
  // zero changes anywhere flags are *read*.
  final Map<String, bool> _flags;
  LocalFeatureFlags(this._flags);

  @override
  bool isEnabled(String key) => _flags[key] ?? false;
}

// Usage anywhere in feature code:
if (getIt<FeatureFlags>().isEnabled('new_checkout_flow')) { ... }
```

---

## 26. Analytics Example

Already shown in §17 (`AnalyticsService`). Usage inside a Cubit:
```dart
Future<void> onAddToCart(Product product) async {
  final result = await _addToCartUseCase(product);
  if (result.isOk) {
    await _analytics.logEvent('add_to_cart', params: {'product_id': product.id});
  }
}
```
Business logic never imports `firebase_analytics`. That import exists in exactly one file: the `prod`-environment implementation.

---

## 27. Crash Reporting Example

```dart
abstract class CrashReporter {
  Future<void> recordError(Object error, StackTrace stack, {bool fatal = false});
  Future<void> setUserId(String? id);
}

// Wired once, in main.dart:
FlutterError.onError = (details) => getIt<CrashReporter>().recordError(
      details.exception, details.stack ?? StackTrace.empty, fatal: true,
    );
PlatformDispatcher.instance.onError = (error, stack) {
  getIt<CrashReporter>().recordError(error, stack, fatal: true);
  return true;
};
```
Same swap-later pattern: a `NoopCrashReporter` in dev, `FirebaseCrashlyticsReporter` behind `@Environment('prod')`.

---

## 28. Testing Strategy

| Layer | What to test | Realistic solo-dev coverage target |
|---|---|---|
| Domain (entities, UseCases) | 100% — pure Dart, no mocking needed, cheapest tests you'll ever write | **95–100%** |
| Data (repositories, datasources) | Success + each Failure branch, using `mocktail` for Dio/Hive | **75–85%** — diminishing returns past "every branch hit once" |
| Bloc/Cubit | `bloc_test` — given state X, when event Y, expect states [Z] | **80%+** on Cubits with real logic; skip exhaustive tests on pass-through Cubits (§21) |
| Widget | Critical interactive flows only (login form validation, checkout button states) | **Cover the 20% of screens that touch money or auth**, not all of them |
| Golden | Design-system components only (`AppButton`, `AppCard` states) — not full pages, which churn too often to be worth golden-diffing | Every design_system widget, ~10 golden files total |
| Integration | One "happy path" end-to-end per critical journey (login → home → checkout) | 3–5 total, run in CI on every release branch push, not every commit (too slow for solo iteration speed) |

A solo developer chasing 100% everywhere is a common trap — the ROI curve inverts hard past "domain 100%, data ~80%, everything else risk-weighted."

---

## 29. CI/CD Pipeline

```yaml
# .github/workflows/ci.yaml
name: CI
on: [pull_request]
jobs:
  analyze_test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: kuhnroyal/flutter-fvm-config-action@v3   # reads .fvmrc
      - uses: subosito/flutter-action@v2
        with: { flutter-version-file: .fvmrc }
      - run: dart pub global activate melos
      - run: melos bootstrap
      - run: melos run analyze          # flutter analyze across all packages
      - run: melos run format-check     # dart format --set-exit-if-changed
      - run: melos run test             # flutter test --coverage across all packages
```

```yaml
# .github/workflows/release.yaml — triggered on tag push (semantic version)
name: Release
on:
  push:
    tags: ['v*.*.*']
jobs:
  build_release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: melos bootstrap
      - run: flutter build appbundle --release --flavor prod -t apps/mobile/lib/main_prod.dart
      # iOS build step requires macOS runner + signing secrets — omitted here, documented in RELEASE.md
```

Conventional Commits (`feat:`, `fix:`, `chore:`) drive automatic changelog + semantic version bump via `melos version` — no manual version bumping across packages.

---

## 30. Release Strategy

- **Flavors:** `dev` / `staging` / `prod`, each with its own `main_<flavor>.dart` entrypoint, app icon badge, and `--dart-define` API base URL. Never a hardcoded URL — `Env.current.apiBaseUrl` always.
- **Release cadence for a solo dev:** ship `staging` builds continuously (every merge to `main` via CI → internal testers), promote to `prod` manually, weekly-or-slower. Don't automate prod releases until you have a team big enough to want to lose that control point.
- **Rollback plan:** keep the previous prod `.aab`/`.ipa` artifact in CI storage for 90 days; a broken release is a re-upload of the previous artifact, not a git revert + rebuild under pressure.

---

## 31. Versioning Strategy

- **App version:** SemVer (`MAJOR.MINOR.PATCH+BUILD`) in `pubspec.yaml`, bumped by `melos version` from Conventional Commits.
- **Package versions (internal):** path-dependency during development (fast iteration, no publish step), switched to pinned git/pub versions only if a package is ever extracted for reuse in another project.
- **API versioning:** the backend's concern, but the app pins to `/v1/` explicitly in `Env` — an API version bump is a config change, not a code change.

---

## 32. Scaling Strategy (1 → 100 Features)

| Feature count | What changes |
|---|---|
| 1–10 | Exactly this kit. One `shared` package, one `core`, features added one at a time. |
| 10–30 | Group related features into sub-monorepo "domains" if navigation between them gets tangled (e.g. `feature_checkout`, `feature_cart`, `feature_payment` might share a `commerce_shared` package). Still one app. |
| 30–60 | Consider splitting `apps/mobile` into `apps/mobile` + `apps/desktop` only if the UX genuinely diverges enough to need different shells — not by default, since Flutter's responsive layer already handles most of this in one app. |
| 60–100 | This is team territory, not solo. At this size, feature packages get their own CI pipelines (`melos run test --scope=feature_x`), and a second developer's onboarding is measured in the same "30-minute test," per feature, not per repo. |

The folder structure and dependency direction never change across this table — that's the entire point of deciding it up front.

---

## 33. Long-Term Maintenance Strategy

- **Quarterly dependency audit:** `melos exec -- flutter pub outdated`, budget half a day per quarter. Don't auto-upgrade on a schedule shorter than that — churn has a cost too.
- **Flutter stable channel only**, upgraded within 2–4 weeks of a new stable release, never on release day (let the ecosystem's plugins catch up first).
- **ADRs (Architecture Decision Records)** live as dated entries at the bottom of this file (§ADR Log below) — every "why did we do it this way" question gets answered by one file, not by archaeology through git blame.
- **The abandonment-risk check** (this document's whole opening argument) — re-run it yearly for every non-Flutter-team-maintained dependency (Hive-family, DI codegen, HTTP client). A dependency going quiet for 12+ months with open unaddressed issues is your cue to plan a swap before it's forced.

---

## 34. Common Mistakes

1. **Adding a UseCase for every single Cubit method** "because Clean Architecture says so" — re-read §21.
2. **Business logic creeping into `didChangeDependencies` or `initState`** because "it's just this one screen" — it's never just one screen five features later.
3. **Catching exceptions in the presentation layer** instead of the repository — breaks the one invariant (`Result` only, above data layer) that makes error handling predictable.
4. **Global `BlocProvider` at the app root for feature-scoped Cubits** — leaks memory and state across navigation; scope Cubits to the route/page that needs them.
5. **Committing generated files** (`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `*.module.dart`) inconsistently — pick one policy and apply it repo-wide via `.gitignore`, not per-package. This project's actual `.gitignore` (ADR-007) is the source of truth here, and reads exactly as follows — copied, not paraphrased, so this section can't quietly drift from the code again: "build_runner output (freezed, json_serializable, injectable, hive_ce) — regenerated by `melos run gen` (also a CI step, so this doesn't reintroduce the 'no build step' problem the old commit-them policy was for), never hand-edited, so committing it was just diff noise + a staleness trap (a stale committed file can silently mask a forgotten regen)." Deliberately **not** ignored, straight from the same file: "`*.g.yaml` (hive_ce_generator's schema-migration tracking file, e.g. `home_item_model.g.yaml`): unlike the patterns above, its own generated header says to check it in — it's what lets hive_ce keep a Hive type's field indices/typeId stable across regenerations, so previously-persisted data stays readable after the model changes. Ignoring it would look fine today (nothing has migrated yet) but is a real risk the first time a `HomeItemModel`-style class adds/reorders a field."
6. **Treating `hive`/`isar` as permanent** without knowing their maintenance status — see the opening audit.

---

## 35. Trade-Off Analysis

| Decision | You gain | You pay |
|---|---|---|
| Clean Architecture layers | Testability, swappable data sources, survives 5+ years without a rewrite | More files per feature, ~20% more typing per CRUD screen |
| flutter_bloc over Riverpod | Explicit, auditable event trail (regulatory value) | More boilerplate per feature than Riverpod would cost |
| get_it + injectable (codegen DI) | No manual wiring, environment-based swapping | A build_runner step in your dev loop — `melos run gen` right after clone/pull, since generated output isn't committed (ADR-007) |
| Monorepo + Melos | Reuse-ready, enforced package boundaries | Slightly slower `pub get` across packages; one more tool to learn on day 1 |
| Result/Failure over exceptions | Compiler-enforced error handling, no forgotten try/catch | More verbose call sites (`result.fold(...)` everywhere) |

---

## 36. Best Practices

- Effective Dart + strict lints (`analysis_options.yaml` extends `package:lints/recommended.yaml` plus explicit `avoid_dynamic_calls`, `prefer_relative_imports` off in favor of package imports for clarity across packages).
- No widget over ~150 lines — if `build()` is scrolling, extract a private widget class (not a private method — private *classes* get their own `const` optimization and their own golden tests).
- Every `Failure` message is written for a human end user or logged separately for a developer — never leak a raw exception `.toString()` into a SnackBar.
- Feature packages never import each other directly — communication goes through `shared` (router extras, DI-resolved services) or `core` (shared value types).

---

## 37. Future Improvements

Deliberately **not** built now, because YAGNI — but the architecture leaves room without a rewrite:

- **Code push / hot patch** for critical bug fixes without app store review — evaluate only if release cadence becomes a real business bottleneck.
- **Modular feature delivery** (deferred components / dynamic feature modules) — only relevant past the "60–100 features" scale row in §32.
- **GraphQL instead of REST** — `ApiClient` already isolates the network shape behind repository interfaces; swapping Dio+REST for a GraphQL client touches only `data/datasources`, never `domain` or `presentation`.
- **Full offline-first sync engine** (CRDT-based or otherwise) — the queue-and-flush design in §11 is the seed; a real conflict-resolution engine is only worth building once a feature genuinely needs concurrent multi-device edits.

---

## ADR Log

**ADR-001 — Reject `dartz`, use hand-rolled `Result<F,S>`.**
*Context:* Spec required `Either<Failure, Success>` via dartz. *Decision:* dartz is unmaintained since ~2016 (evidenced by community forks `dart3z`, `dartz_plus`); Dart 3 sealed classes + pattern matching give the same safety with zero dependency. *Status:* Accepted.

**ADR-002 — Reject original `hive`/`hive_flutter`, use `hive_ce`/`hive_ce_flutter`.**
*Context:* Original Hive author moved on to Isar, then Isar stalled too; a community fork (Hive CE) now carries maintenance. *Decision:* pin to the CE packages from day one rather than migrating under pressure later. *Status:* Accepted.

**ADR-003 — Keep flutter_bloc over Riverpod.**
*Context:* Riverpod is the lower-boilerplate 2026 default for greenfield apps; Bloc remains the stronger fit for audited/regulated domains (fintech, healthcare, government — this project's explicit targets). *Decision:* Bloc, revisit if the product's compliance requirements change. *Status:* Accepted, documented as reversible.

**ADR-004 — UseCase layer is optional, not mandatory, per Cubit method.**
*Context:* A UseCase wrapping a single pass-through repository call adds a file and a test with no behavioral value. *Decision:* UseCases required only for real orchestration/business rules; trivial CRUD may call the repository directly from the Cubit. *Status:* Accepted.

**ADR-005 — Use freezed 3.x syntax: `abstract class` / `sealed class`, no `.when()`/`.whenOrNull()`.**
*Context:* Original draft of this document used freezed 2.x syntax (`class X with _$X`, `.whenOrNull()` in listeners). Freezed 3.0 (current stable: 3.2.5) made this a breaking change: single-constructor classes must be declared `abstract class`, multi-constructor union types (like Bloc states) must be declared `sealed class`, and `.when()`/`.map()`-family methods are removed in favor of Dart 3's native `switch` pattern matching. *Decision:* All freezed models and states in this document (and in code Claude Code generates from it) use the 3.x syntax and native pattern matching. *Status:* Accepted — corrected after the `authentication` package stage, before any freezed code was written for it.

**ADR-006 — Enforce FVM for every command; pin Flutter to an exact version, not a channel.**
*Context (2026-07-07):* An audit found `.fvmrc` present but set to `"flutter": "stable"` — a channel alias, not a fixed version — and every `flutter`/`dart`/`melos` command run in earlier stages used the machine's ambient global Flutter install with no `fvm` prefix at all. Both happened to resolve to the same build (3.44.4, revision `ad70ec4617`), so nothing broke yet, but purely by coincidence: the two are independent SDK checkouts that could silently diverge the moment either one is upgraded on its own. Separately, `packages/core` and `packages/authentication` had `freezed` pinned to a prerelease `^4.0.0-dev.3` (paired with a mismatched `freezed_annotation ^3.0.0`) — against this project's own no-prerelease-dependency rule. Correcting that to stable `freezed ^3.2.5` then collided with `injectable_generator ^3.1.0`, whose `lean_builder ^1.2.0` requires `analyzer ^13.0.0` — outside freezed 3.2.5's `<13.0.0` ceiling. *Decision:* `.fvmrc` is hard-pinned to an exact version (`3.44.4`) rather than a channel. Every local command goes through `fvm flutter`, `fvm dart`, or `fvm exec melos run <name>` — never bare `flutter`/`dart`/`melos` (see [README.md](README.md)). `freezed` is pinned to `^3.2.5` with `freezed_annotation ^3.1.0` everywhere it's used, and `injectable_generator` is pinned to `^3.0.0` (not `^3.1.0`) across every package so its `lean_builder`/`analyzer` requirement stays compatible with freezed. `.github/workflows/ci.yaml` reads the same `.fvmrc` via `kuhnroyal/flutter-fvm-config-action`, before the analyze/test steps, so CI, local dev, and any future teammate's machine all resolve to the identical pinned SDK. *Status:* Accepted.

*Follow-up (2026-07-07) — from documented convention to system-enforced.* The decision above still depended on everyone remembering to type the `fvm`/`fvm exec` prefix by hand, and on two independent installation mechanisms (a local `.fvmrc` pin vs. CI's `flutter-fvm-config-action` + `flutter-action`) that merely happened to agree. Neither was actually enforced by anything. Fixed three ways: (1) `fvm flutter`/`fvm dart` is now baked directly into every `melos.scripts` entry's `run:` body in the root `pubspec.yaml` — `melos run analyze`/`test`/`format`/`gen` use the pinned SDK even if the caller never types `fvm` at all, because the invocation lives inside the script, not in the caller's typing discipline. (2) [`tool/verify_fvm.dart`](tool/verify_fvm.dart) reads `.fvmrc`, runs `fvm flutter --version --machine`, and fails loudly (exit 1, with a clear pinned-vs-actual comparison or setup instructions) if FVM isn't installed, isn't pinned, or resolves to the wrong version — exposed as `melos run doctor`, the first command anyone should run after cloning. (3) CI no longer installs Flutter through a second, parallel mechanism: `.github/workflows/ci.yaml` bootstraps a plain Dart SDK (`dart-lang/setup-dart`, version-irrelevant, used only to run `dart pub global activate fvm`), then runs `fvm install` — which reads `.fvmrc` directly — and gates on `fvm dart run tool/verify_fvm.dart` before analyze/test/gen run at all. `.fvmrc` is now the *only* place a Flutter version is chosen, read by exactly one mechanism (fvm itself) in both places it matters. Verified empirically: `melos run analyze`/`melos run test`, invoked with zero `fvm` typed by the caller, were traced via `--verbose` output to actually invoke `C:\...\fvm\versions\3.44.4\bin\cache\dart-sdk\bin\dart` — a physically different SDK checkout than the ambient global `flutter` on PATH — confirming the pin is enforced by the script, not by the caller's discipline. *Status:* Accepted.

**ADR-007 — Don't commit build_runner output (`*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.module.dart`); regenerate via `melos run gen`.**
*Context (2026-07-07):* §34's original guidance was to commit generated code, specifically so CI wouldn't need a build step just to run `analyze`. That justification stopped being true once ADR-006's CI unification added a `melos run gen` step before analyze/test anyway — CI was already paying for the build step, committing the output on top of that was only buying diff noise (nobody reviews generated code line-by-line) and a staleness trap (a committed file can silently mask a forgotten local regen; the source and its generated output can drift and `analyze` won't catch it if the stale file still happens to compile). *Decision:* `.gitignore` now excludes `*.freezed.dart`, `*.g.dart`, `*.config.dart`, `*.module.dart` repo-wide. Anyone cloning the repo (or pulling a change that touched a `@freezed`/`@injectable`/`@JsonSerializable` class) runs `melos run gen` before anything else needs it — already true in practice since `melos run doctor` → `get` → `gen` is the documented post-clone sequence (README). The one exception: hive_ce_generator's `*.g.yaml` schema-migration file (e.g. `home_item_model.g.yaml`) stays tracked, because its own generated header says to — it's what keeps a Hive type's field indices/typeId stable across regenerations so previously-persisted data stays readable after the model changes; the same "don't commit generated files" logic doesn't apply to a file whose entire purpose is being a stable, versioned record. *Status:* Accepted.

*Follow-up (2026-07-07) — CI never actually ran this, and §34 had quietly drifted from what `.gitignore` says.* Two problems surfaced together. First: `.github/workflows/ci.yaml` was still `on: [pull_request]` only, so every ADR-006/ADR-007 fix so far — the FVM pin, the freezed/injectable_generator version fix, ungenerating the committed build output — had only ever been exercised on a local machine, never on a clean GitHub Actions runner with no pre-existing `.dart_tool`/pub cache. A direct push to `master` (this repo's confirmed default branch, checked via `git remote show origin` rather than assumed) skipped CI entirely. *Decision:* `on:` now triggers on both `push: branches: [master]` and `pull_request`, so a clean-room run is guaranteed at least once per push to the branch everything else depends on. Second: §34's mistake-list entry for this same ADR had been paraphrased from memory rather than copied from the `.gitignore` comments it's describing — accurate at the time, but exactly the kind of doc/code drift ADR-005 and ADR-006 already had to correct once each. §34 point 5 now quotes the `.gitignore` comments directly instead of re-explaining them, so the two can't silently diverge again. *Status:* Accepted.

**ADR-008 — `gen` uses `fvm flutter pub run build_runner build`, not `fvm dart run`.**
*Context (2026-07-07):* ADR-007's follow-up added a real push-to-`master` CI trigger, and the very first clean-room run it produced failed at `melos run gen`: `Because feature_home requires the Flutter SDK, version solving failed. Flutter users should use 'flutter pub' instead of 'dart pub'.` This is a known, still-open Dart SDK bug — [dart-lang/sdk#62808](https://github.com/dart-lang/sdk/issues/62808): `dart run` doesn't set the `FLUTTER_ROOT`/`PUB_ENVIRONMENT` environment that pub needs to resolve an `sdk: flutter` dependency, even when the `dart` binary invoked is the one bundled inside a Flutter SDK checkout (`fvm dart` included) — only the `flutter` wrapper command sets that up. Every package here except pure-Dart `core` depends on `flutter: sdk: flutter` (`feature_home`, `authentication`, `design_system`, `mobile`), so `fvm dart run build_runner build` was broken for all of them the whole time — it just never surfaced locally, because this machine's ambient `FLUTTER_ROOT` (left over from the pre-existing global Flutter install noted in ADR-006's audit) was masking it. A clean CI runner has no such leftover, so it was the first environment to actually hit the bug. *Decision:* `gen`'s script body now runs `fvm flutter pub run build_runner build --delete-conflicting-outputs` instead of `fvm dart run build_runner build --delete-conflicting-outputs` — confirmed working per [dart-lang/sdk#61857](https://github.com/dart-lang/sdk/issues/61857). `flutter pub run` prints its own deprecation warning (Flutter's docs steer you toward `dart run` for exactly this reason, normally) — that warning is expected and safe to ignore here; it's the one case where the "deprecated" path is the one that actually works. `analyze` and `format` are deliberately left on `fvm dart analyze`/`fvm dart format` — the bug is specific to `dart run`'s implicit pub resolution step, not to `dart analyze`/`dart format`, which don't trigger it. *Revert trigger:* once dart-lang/sdk#62808 is closed upstream and a fixed Dart SDK is what `.fvmrc`'s pinned Flutter version bundles, switch `gen` back to `fvm dart run build_runner build` — check the issue link above rather than guessing whether it's fixed. *Status:* Accepted.

*Follow-up (2026-07-07) — the `gen`-only fix above wasn't the actual bug.* Pushing it produced the *identical* error, and the failed step's raw log settled it: zero output before the error — no `melos exec` banner, no per-package progress, not even for `core` (which needs no Flutter SDK and would run first). The error fires ~250ms after the step starts, far too fast for `build_runner` to have even loaded. `melos` itself was dying during its own startup/workspace resolution, before ever reaching the `run:` command this ADR's original fix changed. *Root cause:* CI installs `melos` via `dart pub global activate melos`, run under `dart-lang/setup-dart`'s bootstrap SDK — a plain Dart install with no Flutter awareness at all (not even the "raw dart-sdk-inside-a-Flutter-checkout" case ADR-008 originally targeted). `melos` apparently shells out to plain `dart pub` internally while resolving the workspace, and hits dart-lang/sdk#62808 itself, for the same reason `build_runner` did. This also explains why local runs never surfaced it: this machine's `melos` shim calls bare `dart`, which resolves through the *ambient* legacy Flutter install's own `bin/dart` wrapper (not `fvm dart`) — coincidentally Flutter-aware, nothing to do with anything this repo controls. *Decision:* stop globally activating `melos` in CI. It's already a pinned `dev_dependency` of the root workspace (resolved by `fvm flutter pub get`), so every `melos run <name>` step now runs as `fvm flutter pub run melos run <name>` instead — melos's *entire* process tree, not just whatever command follows `melos exec --`, runs under `flutter`'s Flutter-aware environment. Confirmed locally for `gen`, `analyze`, `format`, and `test` individually via this exact invocation before pushing. *Status:* Accepted.

*Follow-up #2 (2026-07-07) — routing melos through `pub run` broke a different melos internal.* Pushing the fix above got further (`melos run gen`'s own banner and `melos exec` line printed — confirming melos's *startup* really was the earlier problem) but still failed, now with `ERROR: /bin/sh: 1: eval: melos: not found` from inside melos's own per-package dispatch. `--order-dependents`/`--depends-on` orchestration apparently re-invokes `melos` as a subprocess internally, assuming it's the properly-installed global binary — running it via `pub run` instead removed the bare `melos` on PATH that self-reference needs. Two different things needed fixing, and fixing one broke the other. *Decision:* revert to globally activating `melos` (`dart pub global activate melos`, bare `melos run <name>` steps, as originally), but add one step before it: `echo "$(fvm flutter --version --machine | jq -r '.flutterRoot')/bin" >> "$GITHUB_PATH"`. That's the *actual* Flutter SDK's `bin/` directory — distinct from `bin/cache/dart-sdk/bin`, which is all `fvm dart`/`fvm flutter` ever touch — and it holds Flutter's own `dart`/`flutter` wrapper scripts, the ones that set `FLUTTER_ROOT`/`PUB_ENVIRONMENT` before handing off to the real SDK binary. Prepending it to `PATH` means *any* bare `dart` call in the job's process tree from that point on — melos's internal self-invocation included — resolves through the wrapper instead of the raw SDK binary, fixing the root cause once instead of routing each individual tool through `flutter pub run`. *Status:* Accepted, pending the CI run this produces actually going green (see the ADR-008 entries' shared context — two prior "fixes" both looked reasonable and both weren't; treat this one as unconfirmed until watched pass for real, same standard as everything else in this ADR).

*Follow-up #3 (2026-07-07) — the `FLUTTER_ROOT`-on-PATH fix worked, and got further than either prior attempt: `gen` and `analyze` both passed for real in CI.* `format` then failed — a genuinely different, unrelated issue. `dart format --set-exit-if-changed` flagged `*_module.dart` (injectable's micro-package module output, one per package that has one: `core`, `authentication`, `feature_home`, `shared`) as needing changes. This isn't a Flutter-SDK-resolution problem at all: injectable_generator's raw output isn't quite `dart format`-clean the moment `build_runner` writes it, so every fresh `gen` needs one format pass to converge — and since ADR-007 stopped committing generated files, *every* environment (CI, a fresh clone, right after `git pull`) now regenerates from scratch and hits this. Checked whether `analysis_options.yaml` supports a `formatter: exclude:` list to skip generated files in the format check the way `analyzer: exclude:` does for `dart analyze` — tested it directly (added the key, regenerated, ran `dart format --set-exit-if-changed .`) and the excluded file got reformatted anyway, so this Dart SDK (3.12.2) doesn't honor that key for `dart format`; not a valid fix, reverted. *Decision:* `gen`'s script now chains `&& fvm dart format .` after the `build_runner` pass, so generated output is immediately formatted (not just gitignored) the moment it's created — the separate `format` check step (which gates hand-written code, not machine output) always sees already-clean files by the time it runs. Confirmed locally: `melos run gen` then `melos run format` reports `0 changed` across all 6 packages. *Status:* Accepted, same caveat as Follow-up #2 — watch the CI run this produces before trusting it.

*Confirmed (2026-07-07):* [Run 28852744324](https://github.com/MIT2010/flutter-monorepo/actions/runs/28852744324) went green end to end — `gen`, `analyze`, `format`, and `test` all passed on a real clean-room runner. Four commits and four separate real-CI round-trips to get here (the `dart run` → `flutter pub run` swap, then the melos-invocation fix, then its own revert-and-retarget, then the format-after-gen fix) — every one of them looked like the actual fix in isolation, and three weren't. The lesson worth keeping, not just the fix: a clean-room CI runner will find every place "it works on my machine" was hiding an assumption, one at a time — budget for that instead of expecting the first plausible diagnosis to be the last one.

**ADR-009 — The Mason `feature` brick generates the minimal proven slice only; UseCases, caching, and app wiring stay manual.**
*Context (2026-07-08):* §14 promised a Mason brick, but it was deliberately not built until two features existed manually — `feature_home` (offline cache, no UseCase) and `feature_profile` (no cache, one justified UseCase) — because a generator codifies whatever pattern it's built from, and codifying an unproven pattern just mass-produces mistakes. With both features green in CI, the shared skeleton between them is now a fact, not a guess. *Decision:* `bricks/feature` (registered in root `mason.yaml`, cache in gitignored `.mason/`) scaffolds exactly the slice both features share — entity → repository contract + impl → remote datasource → freezed model → DI micro-package marker → Cubit + sealed State → page → repository-test skeleton, with pubspec pre-wired to `core`/`design_system`/`shared` and `resolution: workspace`. A post-gen hook (structure taken from the official `mason new --hooks` scaffold: top-level `run(HookContext)` in `hooks/post_gen.dart`, `hooks/pubspec.yaml` depending on `mason`) auto-adds the package to the root pubspec's `workspace:` list and prints the `fvm flutter pub get` → `melos run gen` reminder. The brick deliberately does **not** generate: a UseCase (per-method judgment call, §21/ADR-004 — a generator that emits one for every feature would institutionalize exactly the reflex those decisions exist to prevent), local caching (§11 — most features don't need it; `feature_home` is the reference when one does), or `apps/mobile` wiring (route, pubspec dependency, `Feature<Name>PackageModule` in `injection.dart` — composition-root edits shouldn't be done by blind text insertion into files that change shape). *Verified with a real throwaway generation, not assumed:* `mason make feature --feature_name=throwaway_test -o .` generated 13 files, the hook genuinely edited `workspace:`, and `pub get`/`gen`/`analyze`/`format`/`test` all passed with the generated package included (its 2 skeleton tests ran green) before the throwaway was deleted again. That test also caught a real bug: `gen`'s trailing format pass used `dart format .`, which dies on `__brick__`'s mustache templates (not valid Dart) — fixed by pointing it at explicit source roots (`packages apps tool`) instead of `.`. *Status:* Accepted.

**ADR-010 — Wiring a feature into `apps/mobile` is a separate, mandatory step; "the package is green in CI" is not "the feature is reachable."**
*Context (2026-07-08):* `feature_profile` shipped complete — domain/data/presentation layers, 10 passing tests, green on its own in CI — and was still **totally invisible to any user**. It was never added to `apps/mobile`'s pubspec, its `FeatureProfilePackageModule` was never folded into `injection.dart`'s `configureDependencies`, and there was no `/profile` route or any UI path to reach it. Nothing failed, because nothing referenced it: a package that compiles and tests in isolation produces exactly zero signal about whether it's connected to the running app. This is a genuinely dangerous failure mode precisely *because* everything upstream is green — package-level CI passing feels like "done," so the composition-root wiring is the step most likely to be silently skipped. `feature_home` happened to get wired at the same time it was built, so the gap never showed; `feature_profile`, built as a standalone exercise, exposed it. *Decision:* every new feature — whether hand-written or generated by the Mason brick (ADR-009, which deliberately does *not* generate this wiring) — requires four explicit composition-root edits before it counts as done, all in `apps/mobile`: (1) add `feature_<name>: path: ../../packages/feature_<name>` to `pubspec.yaml`; (2) import its generated `Feature<Name>PackageModule` and add `ExternalModule(...)` to `injection.dart`'s `externalPackageModulesBefore`; (3) add its `GoRoute` to `app.dart`'s route list; (4) give it a reachable entry point in the UI (a button/route from an already-reachable screen — a feature the user can't navigate to is as useless as one that doesn't exist). And the acceptance bar is not `analyze`/`test` passing — it's *seeing the screen render in a running app*: `melos run analyze`/`test` green tells you the code is correct in isolation, never that it's reachable. This feature was verified by running the real app against a local mock API, logging in, tapping the new profile icon on the home screen, and confirming the profile page rendered with live-fetched data (`GET /profile` → name/email/bio/phone populated) and that Save round-tripped (`PUT /profile`) without error — the same "drive the actual flow, don't trust the tests" standard ADR-008's saga hammered in for CI. *Status:* Accepted.

*(Add new entries here, dated, every time a future-you would otherwise wonder "why did I do it this way." This is the single document that makes the 30-minute test possible in year five.)*
