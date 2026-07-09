import 'package:flutter/material.dart';

/// Wraps [TextField] with the same named-parameter shape as its Material
/// counterpart so it never feels like a foreign DSL (§16).
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscure;
  final String? errorText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscure = false,
    this.errorText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
