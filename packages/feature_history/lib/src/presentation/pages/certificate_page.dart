import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared/shared.dart';

import '../cubit/certificate_cubit.dart';
import '../cubit/certificate_state.dart';

/// Migrated from the old app's `test/presentation/pages/certificate_page.dart`
/// — a read-only PDF viewer for `TestHistoryItem.certificateUrl`. Old app
/// used `syncfusion_flutter_pdfviewer`; this uses `pdfx` instead
/// (deliberate substitution, not a like-for-like port —
/// docs/qa/history.md): Syncfusion's package carries commercial-license
/// terms that don't belong as a default in a general-purpose OSS starter
/// kit, and `pdfx` renders via `pdfium` without embedding a native
/// platform view, avoiding the native-integration class of complexity this
/// migration project has been deliberately cautious about elsewhere
/// (MIGRATION_LOG.md's `camera` findings).
///
/// Reads `url` from the route's query parameter — same pattern as the old
/// app (`GoRouterState.of(context).uri.queryParameters['url']`).
class CertificatePage extends StatelessWidget {
  const CertificatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final url = GoRouterState.of(context).uri.queryParameters['url']!;

    return BlocProvider(
      create: (_) => getIt<CertificateCubit>()..load(url),
      child: const CertificateView(),
    );
  }
}

/// Split from [CertificatePage] (left un-exported from the barrel) so
/// widget tests can drive it directly with a fake `CertificateCubit` via
/// `BlocProvider.value`, without going through `get_it` or a real route —
/// same pattern as every other feature's page.
class CertificateView extends StatefulWidget {
  const CertificateView({super.key});

  @override
  State<CertificateView> createState() => CertificateViewState();
}

class CertificateViewState extends State<CertificateView> {
  PdfController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sertifikat')),
      body: BlocBuilder<CertificateCubit, CertificateState>(
        builder: (context, state) => switch (state) {
          CertificateInitial() || CertificateLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          CertificateError(:final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: () {
                      final url = GoRouterState.of(
                        context,
                      ).uri.queryParameters['url']!;
                      context.read<CertificateCubit>().load(url);
                    },
                  ),
                ],
              ),
            ),
          ),
          CertificateLoaded(:final bytes) => _buildPdfView(bytes),
        },
      ),
    );
  }

  Widget _buildPdfView(Uint8List bytes) {
    // Built once, not per-rebuild: constructing a fresh PdfController (and
    // re-parsing the bytes via PdfDocument.openData) on every BlocBuilder
    // rebuild would be wasteful and reset scroll/page position.
    _controller ??= PdfController(document: PdfDocument.openData(bytes));
    return PdfView(controller: _controller!);
  }
}
