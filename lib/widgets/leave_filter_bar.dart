import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// 휴가 신청 목록 화면(내 신청/전체 신청)에서 공통으로 쓰는
/// 상태 필터 드롭다운 + 기간 선택 버튼 + 선택된 기간 표시 바.
class LeaveFilterBar extends StatelessWidget {
  final List<Map<String, String?>> statusOptions;
  final String? selectedStatus;
  final ValueChanged<String?> onStatusChanged;
  final DateTimeRange? dateRange;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;

  const LeaveFilterBar({
    super.key,
    required this.statusOptions,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.dateRange,
    required this.onPickDateRange,
    required this.onClearDateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: DropdownButton<String?>(
                    value: selectedStatus,
                    items: statusOptions.map((option) {
                      return DropdownMenuItem<String?>(
                        value: option['value'],
                        child: Text(option['label']!),
                      );
                    }).toList(),
                    onChanged: onStatusChanged,
                    underline: Container(height: 1, color: Colors.grey),
                    isExpanded: true,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.calendar_today, size: 20),
                  label: const Text('기간 선택', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(100, 36),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (dateRange != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('${formatDateDashed(dateRange!.start)} — ${formatDateDashed(dateRange!.end)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onClearDateRange,
                  child: const Text('지우기',
                      style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
