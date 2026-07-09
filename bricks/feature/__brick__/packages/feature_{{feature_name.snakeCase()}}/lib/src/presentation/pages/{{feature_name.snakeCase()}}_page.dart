import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../cubit/{{feature_name.snakeCase()}}_cubit.dart';
import '../cubit/{{feature_name.snakeCase()}}_state.dart';

class {{feature_name.pascalCase()}}Page extends StatelessWidget {
  const {{feature_name.pascalCase()}}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<{{feature_name.pascalCase()}}Cubit>()..get{{feature_name.pascalCase()}}(),
      child: const {{feature_name.pascalCase()}}View(),
    );
  }
}

/// Split from the page (and left un-exported from the package barrel) so
/// widget tests can drive it directly with a fake cubit via
/// `BlocProvider.value`, without going through `get_it` — same pattern as
/// every other feature here.
class {{feature_name.pascalCase()}}View extends StatelessWidget {
  const {{feature_name.pascalCase()}}View({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{{feature_name.titleCase()}}')),
      body: BlocBuilder<{{feature_name.pascalCase()}}Cubit, {{feature_name.pascalCase()}}State>(
        builder: (context, state) => switch (state) {
          {{feature_name.pascalCase()}}Initial() ||
          {{feature_name.pascalCase()}}Loading() =>
            const Center(child: CircularProgressIndicator()),
          {{feature_name.pascalCase()}}Error(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () =>
                        context.read<{{feature_name.pascalCase()}}Cubit>().get{{feature_name.pascalCase()}}(),
                  ),
                ],
              ),
            ),
          ),
          // TODO: replace with this feature's real UI.
          {{feature_name.pascalCase()}}Loaded(:final {{feature_name.camelCase()}}) => Center(
            child: Text({{feature_name.camelCase()}}.id),
          ),
        },
      ),
    );
  }
}
