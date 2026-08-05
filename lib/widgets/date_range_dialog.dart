import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DateRangeDialog extends StatefulWidget {
  const DateRangeDialog({
    super.key,
    this.initialRange,
  });

  final DateTimeRange? initialRange;

  @override
  State<DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<DateRangeDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;

  @override
  void initState() {
    super.initState();

    _startController = TextEditingController(
      text: _formatDate(widget.initialRange?.start),
    );

    _endController = TextEditingController(
      text: _formatDate(widget.initialRange?.end),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';

    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  DateTime? _parseDate(String value) {
    try {
      final parts = value.split('-');

      if (parts.length != 3) return null;

      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );

      // 실제 존재하는 날짜인지 확인
      if (date.year != int.parse(parts[0]) ||
          date.month != int.parse(parts[1]) ||
          date.day != int.parse(parts[2])) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final current = _parseDate(controller.text) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  void _confirm() {
    final start = _parseDate(_startController.text);
    final end = _parseDate(_endController.text);

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("날짜를 yyyy-MM-dd 형식으로 입력해주세요."),
        ),
      );
      return;
    }

    if (start.year < 1900 || end.year > 3000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("유효하지 않은 범위입니다."),
        ),
      );
      return;
    }

    if (start.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("시작일은 종료일보다 이전이어야 합니다."),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      DateTimeRange(
        start: start,
        end: end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("기간 선택"),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDateField(
              label: "시작일",
              controller: _startController,
            ),
            const SizedBox(height: 16),
            _buildDateField(
              label: "종료일",
              controller: _endController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소"),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text("확인"),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _DateFormatter(),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: "yyyy-MM-dd",
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _pickDate(controller),
        ),
      ),
    );
  }
}

class _DateFormatter extends TextInputFormatter {
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