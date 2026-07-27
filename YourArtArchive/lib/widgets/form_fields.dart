import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.caption,
  });

  final String title;
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 14),
        ...children.expand((child) => [child, const SizedBox(height: 14)]),
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.inputFormatters,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
        alignLabelWithHint: (maxLines ?? 1) > 1,
      ),
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
    );
  }
}

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T value) labelFor;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

class RatingDropdown extends StatelessWidget {
  const RatingDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.label = 'Rating',
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool required;
  final String label;

  @override
  Widget build(BuildContext context) {
    final values = <int?>[
      if (!required) null,
      ...List.generate(10, (i) => i + 1),
    ];
    return DropdownButtonFormField<int?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.star_border_rounded),
      ),
      items: values
          .map(
            (rating) => DropdownMenuItem<int?>(
              value: rating,
              child: Text(rating == null ? 'Not rated' : '$rating / 10'),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      validator: required
          ? (rating) => rating == null ? 'Choose a rating from 1 to 10' : null
          : null,
    );
  }
}

class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel = 'Cancel',
    this.onSecondary,
    this.busy = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 440;
        final primary = FilledButton(
          onPressed: busy ? null : onPrimary,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(primaryLabel),
        );
        final secondary = secondaryLabel == null
            ? null
            : OutlinedButton(
                onPressed: busy ? null : onSecondary,
                child: Text(secondaryLabel!),
              );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              if (secondary != null) ...[const SizedBox(height: 10), secondary],
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (secondary != null) ...[secondary, const SizedBox(width: 12)],
            primary,
          ],
        );
      },
    );
  }
}
