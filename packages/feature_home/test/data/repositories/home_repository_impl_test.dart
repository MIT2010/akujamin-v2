import 'package:core/core.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHomeRemoteDataSource extends Mock implements HomeRemoteDataSource {}

class _MockHomeLocalDataSource extends Mock implements HomeLocalDataSource {}

void main() {
  late _MockHomeRemoteDataSource remote;
  late _MockHomeLocalDataSource local;
  late HomeRepositoryImpl repository;

  const remoteItems = [
    HomeItemModel(id: '1', title: 'Fresh 1', subtitle: 'From network'),
    HomeItemModel(id: '2', title: 'Fresh 2', subtitle: 'From network'),
  ];

  const cachedItems = [
    HomeItemModel(id: '1', title: 'Stale 1', subtitle: 'From cache'),
  ];

  setUpAll(() {
    registerFallbackValue(<HomeItemModel>[]);
  });

  setUp(() {
    remote = _MockHomeRemoteDataSource();
    local = _MockHomeLocalDataSource();
    repository = HomeRepositoryImpl(remote, local);
  });

  group('HomeRepositoryImpl.getFeed — remote succeeds', () {
    test(
      'write-through caches the fresh items and returns Ok(isStale: false)',
      () async {
        when(() => remote.getFeed(page: 1, pageSize: 20)).thenAnswer(
          (_) async => const Ok(
            Pagination(
              items: remoteItems,
              page: 1,
              pageSize: 20,
              totalItems: 2,
            ),
          ),
        );
        when(() => local.cacheItems(any())).thenAnswer((_) async {});

        final result = await repository.getFeed();

        expect(result.isOk, isTrue);
        final feed = (result as Ok<Failure, HomeFeed>).value;
        expect(feed.isStale, isFalse);
        expect(feed.items.map((e) => e.id), ['1', '2']);
        verify(() => local.cacheItems(remoteItems)).called(1);
      },
    );
  });

  group('HomeRepositoryImpl.getFeed — remote fails with NetworkFailure', () {
    test('falls back to the cache and returns Ok(isStale: true) when '
        'something is cached', () async {
      when(
        () => remote.getFeed(page: 1, pageSize: 20),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      when(() => local.getCached()).thenReturn(cachedItems);

      final result = await repository.getFeed();

      expect(result.isOk, isTrue);
      final feed = (result as Ok<Failure, HomeFeed>).value;
      expect(feed.isStale, isTrue);
      expect(feed.items.single.id, '1');
      expect(feed.items.single.title, 'Stale 1');
      verifyNever(() => local.cacheItems(any()));
    });

    test(
      'returns Err when the cache is also empty — nothing to fall back to',
      () async {
        when(
          () => remote.getFeed(page: 1, pageSize: 20),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        when(() => local.getCached()).thenReturn(const []);

        final result = await repository.getFeed();

        expect(result.isErr, isTrue);
        expect(
          (result as Err<Failure, HomeFeed>).failure,
          isA<NetworkFailure>(),
        );
      },
    );
  });

  group('HomeRepositoryImpl.getFeed — remote fails with ServerFailure', () {
    test('returns Err immediately and never reads or writes the cache — a real '
        'server error must surface, not get silently papered over', () async {
      when(() => remote.getFeed(page: 1, pageSize: 20)).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getFeed();

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, HomeFeed>).failure, isA<ServerFailure>());
      verifyNever(() => local.getCached());
      verifyNever(() => local.cacheItems(any()));
    });
  });
}
