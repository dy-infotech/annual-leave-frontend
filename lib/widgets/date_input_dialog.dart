import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DateInputDialog extends StatefulWidget {
  const DateInputDialog({
    super.key,
    this.initialDate,
    this.title = '날짜 선택',
    this.firstDate,
    this.lastDate,
  });

  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;

  @override
  State<DateInputDialog> createState() => _DateInputDialogState();
}

class _DateInputDialogState extends State<DateInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: _formatDate(widget.initialDate),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDate(String text) {
    try {
      final parts = text.split('-');

      if (parts.length != 3) return null;

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final date = DateTime(year, month, day);

      // 실제 존재하는 날짜인지 확인
      if (date.year != year ||
          date.month != month ||
          date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_controller.text) ??
          widget.initialDate ??
          DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: widget.lastDate ?? DateTime(2100),
      locale: const Locale('ko'),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null) {
      _controller.text = _formatDate(picked);
    }
  }

  void _confirm() {
    final date = _parseDate(_controller.text);

    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('날짜를 yyyy-MM-dd 형식으로 입력하세요.'),
        ),
      );
      return;
    }

    Navigator.pop(context, date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            const _DateFormatter(),
          ],
          decoration: InputDecoration(
            hintText: 'yyyy-MM-dd',
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDate,
            ),
          ),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _DateFormatter extends TextInputFormatter {
  const _DateFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 4 || i == 6) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}