import 'package:flutter/material.dart';

class RoundedSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String? text;

  const RoundedSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onClear,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    // Get current theme colors and text styles for adaptability
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      // Increased elevation for a more prominent floating effect
      elevation: 4,
      // Softer shadow color that respects the theme's shadow color
      shadowColor: colorScheme.shadow.withOpacity(0.3),
      borderRadius: BorderRadius.circular(30),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        // Use theme's onSurface color for input text to adapt to light/dark mode
        style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: text,
          // Lighter hint text color for better contrast and subtlety
          hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
          // Use theme's surface color for the background of the input field
          fillColor: colorScheme.surface,
          filled: true,
          // Theme-aware icon colors
          prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.8)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: colorScheme.onSurface.withOpacity(0.8)),
            onPressed: onClear,
          )
              : null,
          // Slightly more vertical padding for a comfortable look
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          // No default border (handled by `OutlineInputBorder` below)
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          // A subtle border when the field is enabled but not focused
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.4), width: 1),
          ),
          // A prominent border using primary color when the field is focused
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          // Border for error state (optional, but good practice)
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: colorScheme.error, width: 2),
          ),
          // Border for focused error state
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: colorScheme.error, width: 2.5),
          ),
        ),
      ),
    );
  }
}