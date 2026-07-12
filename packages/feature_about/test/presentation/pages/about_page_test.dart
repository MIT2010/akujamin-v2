import 'package:bloc_test/bloc_test.dart';
import 'package:feature_about/feature_about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _MockAboutCubit extends MockCubit<AboutState> implements AboutCubit {}

void main() {
  // See design_system's app_markdown_text_test.dart for why this is
  // needed: markdown_widget renders via visibility_detector internally,
  // which polls on a timer that flutter_test flags as a leak otherwise.
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'renders FAQ content as markdown, not plain text — closes the gap '
    'tracked since this pilot first shipped: bold syntax actually '
    'formats, it is not shown as literal "**...**" characters',
    (tester) async {
      final cubit = _MockAboutCubit();
      when(() => cubit.state).thenReturn(
        const AboutState.loaded([
          About(type: 'Umum', text: 'Jawaban dengan **teks tebal**.'),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AboutCubit>.value(
            value: cubit,
            child: const AboutView(),
          ),
        ),
      );

      await tester.tap(find.text('Umum'));
      await tester.pumpAndSettle();

      expect(find.textContaining('teks tebal'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
    },
  );
}
