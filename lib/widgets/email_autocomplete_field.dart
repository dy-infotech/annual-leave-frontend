import 'package:flutter/material.dart';

class EmailAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final InputDecoration? decoration;
  final List<String> domains;

  const EmailAutocompleteField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.decoration,
    this.domains = const [
      'gmail.com',
      'naver.com',
      'daum.net',
      'nate.com',
      'kakao.com',
      'outlook.com',
    ],
  });

  @override
  State<EmailAutocompleteField> createState() =>
      _EmailAutocompleteFieldState();
}

class _EmailAutocompleteFieldState extends State<EmailAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose(); // 위젯 내부에서 만든 것이므로 여기서 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final text = value.text;
        final atIndex = text.indexOf('@');
        if (atIndex < 0) return const Iterable<String>.empty();

        final localPart = text.substring(0, atIndex);
        final typedDomain = text.substring(atIndex + 1);

        final matches = widget.domains
            .where((d) => d.startsWith(typedDomain))
            .map((d) => '$localPart@$d')
            .toList();

        if (matches.length == 1 && matches.first == text) {
          return const Iterable<String>.empty();
        }
        return matches;
      },
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: widget.decoration ??
              const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
          onSubmitted: (_) {
            onFieldSubmitted();
            widget.onSubmitted?.call();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxHeight: 200, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(option,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}