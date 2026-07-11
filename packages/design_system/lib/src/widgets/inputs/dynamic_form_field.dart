import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The three shapes a server-driven form field can render as. `text`
/// covers everything the schema doesn't mark as `date`/`select` — the old
/// app never had a closed type list either, this just names the fallback
/// explicitly instead of leaving it implicit.
enum DynamicFormFieldType { date, select, text }

/// A single selectable option, already resolved to (display label,
/// submit value) — this widget has no notion of cascading/dependent
/// options at all. The caller is responsible for pre-filtering [options]
/// and for ensuring [DynamicFormField.value] is either `null` or present
/// in [options]; a value that isn't present in the list throws inside
/// Flutter's own `DropdownButtonFormField` (proven directly against the
/// SDK, not assumed — see MIGRATION_LOG.md's form_input section).
class DynamicFormOption {
  final String label;
  final String value;
  const DynamicFormOption({required this.label, required this.value});
}

/// Generic renderer for one field of a server-driven dynamic form schema.
/// Designed from scratch as a shared, domain-agnostic primitive — not a
/// copy of the old app's `FormFieldBuilder` (see MIGRATION_LOG.md's
/// "generic by design from day one" note). Takes a typed [onChanged]
/// callback instead of a raw `Cubit` reference, and never does its own
/// value-resolution normalization beyond what's needed to hand
/// [onChanged] an already-submittable value.
///
/// Renders one of three ways based on [type]:
/// - `date`: a date picker, displayed as `d MMMM y`, reported as an ISO
///   `yyyy-MM-dd` string (matches the old app's stored format).
/// - `select` with <= 10 [options]: an inline dropdown.
/// - `select` with > 10 [options], or [type] == `text`: a text field —
///   read-only and opens a searchable picker dialog for large selects,
///   freely editable for plain text.
class DynamicFormField extends StatefulWidget {
  final String label;
  final DynamicFormFieldType type;
  final String? value;
  final List<DynamicFormOption>? options;
  final bool validate;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const DynamicFormField({
    super.key,
    required this.label,
    required this.type,
    required this.value,
    required this.onChanged,
    this.options,
    this.validate = false,
    this.readOnly = false,
  });

  bool get _isSmallSelect =>
      type == DynamicFormFieldType.select && (options?.length ?? 0) <= 10;

  @override
  State<DynamicFormField> createState() => _DynamicFormFieldState();
}

class _DynamicFormFieldState extends State<DynamicFormField> {
  static final _dateFormatter = DateFormat('d MMMM y');

  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    if (!widget._isSmallSelect) {
      _controller = TextEditingController(text: _displayValue(widget.value));
    }
  }

  @override
  void didUpdateWidget(covariant DynamicFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newText = _displayValue(widget.value) ?? '';
      if (_controller?.text != newText) {
        _controller?.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String? _displayValue(String? value) {
    if (value == null) return null;

    if (widget.type == DynamicFormFieldType.date) {
      return _dateFormatter.format(DateTime.parse(value));
    }

    if (widget.type == DynamicFormFieldType.select) {
      final match = widget.options?.where((o) => o.value == value);
      return (match == null || match.isEmpty) ? null : match.first.label;
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.type) {
      DynamicFormFieldType.date => _buildDateField(context),
      DynamicFormFieldType.select when widget._isSmallSelect =>
        _buildInlineDropdown(context),
      _ => _buildTextOrDialogField(context),
    };
  }

  Widget _buildDateField(BuildContext context) {
    return TextField(
      controller: _controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'Masukkan ${widget.label}',
        border: const OutlineInputBorder(),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          initialDate: widget.value != null
              ? DateTime.tryParse(widget.value!)
              : null,
        );

        if (picked != null) {
          widget.onChanged(picked.toIso8601String().split('T').first);
        }
      },
    );
  }

  Widget _buildInlineDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: widget.value,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'Pilih ${widget.label}',
        border: const OutlineInputBorder(),
      ),
      items: (widget.options ?? [])
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      validator: widget.validate
          ? (v) => v == null ? 'Form ini tidak boleh kosong.' : null
          : null,
      onChanged: (v) {
        if (v != null) widget.onChanged(v);
      },
    );
  }

  Widget _buildTextOrDialogField(BuildContext context) {
    final isSelect = widget.type == DynamicFormFieldType.select;

    return TextField(
      controller: _controller,
      readOnly: widget.readOnly || isSelect,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '${isSelect ? 'Pilih' : 'Masukkan'} ${widget.label}',
        border: const OutlineInputBorder(),
      ),
      onChanged: isSelect ? null : widget.onChanged,
      onTap: isSelect
          ? () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (_) => _DynamicFormSearchDialog(
                  label: widget.label,
                  options: widget.options ?? [],
                ),
              );

              if (picked != null) widget.onChanged(picked);
            }
          : null,
    );
  }
}

class _DynamicFormSearchDialog extends StatefulWidget {
  final String label;
  final List<DynamicFormOption> options;

  const _DynamicFormSearchDialog({required this.label, required this.options});

  @override
  State<_DynamicFormSearchDialog> createState() =>
      _DynamicFormSearchDialogState();
}

class _DynamicFormSearchDialogState extends State<_DynamicFormSearchDialog> {
  final _search = TextEditingController();
  late List<DynamicFormOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _search.text.toLowerCase();
    setState(() {
      _filtered = widget.options
          .where((o) => o.label.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _search,
                decoration: InputDecoration(hintText: 'Cari ${widget.label}'),
              ),
              const Divider(),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _filtered
                      .map(
                        (o) => ListTile(
                          title: Text(o.label),
                          onTap: () => Navigator.of(context).pop(o.value),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
