import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

import '../cubit/payment_cubit.dart';
import '../cubit/payment_state.dart';

/// Renders `state.forms` via `DynamicFormField` — the server-driven
/// schema fetched from `GET /tes/pertanyaan`, including the `'psikologi'`
/// field that later drives both the socket channel name and the
/// per-psychologist bank-account lookup.
class DemographyView extends StatelessWidget {
  const DemographyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentCubit, PaymentState>(
      buildWhen: (p, c) => p.forms != c.forms || p.formResults != c.formResults,
      builder: (context, state) {
        if (state.forms.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final cubit = context.read<PaymentCubit>();

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.forms.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final form = state.forms[index];
                  final options = filterCascadingOptions(
                    form,
                    state.formResults,
                  );

                  return DynamicFormField(
                    label: form.display,
                    type: _mapType(form.type),
                    value: state.formResults[form.label],
                    validate: form.validate,
                    readOnly: form.readOnly,
                    options: options
                        ?.map(
                          (o) => DynamicFormOption(
                            label: o.label,
                            value: o.value,
                          ),
                        )
                        .toList(),
                    onChanged: (value) => cubit.setInput(form.label, value),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Selanjutnya',
                loading: state.isLoading,
                onPressed: cubit.goToConfirmation,
              ),
            ),
          ],
        );
      },
    );
  }

  DynamicFormFieldType _mapType(String type) => switch (type) {
    'date' => DynamicFormFieldType.date,
    'select' => DynamicFormFieldType.select,
    _ => DynamicFormFieldType.text,
  };
}
