import 'package:freezed_annotation/freezed_annotation.dart';

part 'intro_entity.freezed.dart';

@freezed
abstract class IntroEntity with _$IntroEntity {
  const factory IntroEntity({String? description, String? imageUrl}) =
      _IntroEntity;
}
