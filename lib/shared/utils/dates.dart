const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "27 Oct 2026".
String fmtDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
