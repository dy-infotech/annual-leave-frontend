import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 전체에서 공유하는 색상 팔레트. 화면에서 색을 직접 쓰기보다 이 값을 우선 사용한다.
class AppColors {
  static const slate = Color(0xFF2B3A4A); // Primary
  static const slateLight = Color(0xFF44576B);
  static const sage = Color(0xFF7FA88A); // 승인/잔여/긍정
  static const amber = Color(0xFFC9A66B); // 대기 상태
  static const coral = Color(0xFFC97B63); // 반려/경고
  static const background = Color(0xFFF7F6F3); // 배경
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF23292F);
  static const textMuted = Color(0xFF8B8F94);
  static const divider = Color(0xFFE8E6E1);
}

/// 앱 공통 Material 3 테마. 슬레이트(남색 계열)를 기준색으로 하고 폰트는 Noto Sans KR을 쓴다.
/// 버튼, 입력창, 카드 등의 모양을 여기서 한 번에 정의하므로 개별 화면에서는 스타일을 덮어쓰지 않는 것이 좋다.
class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme);

    // 슬레이트를 시드로 전체 색 세트를 생성, 파생 색까지 보라 제거
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.slate,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.slate,
      secondary: AppColors.sage,
      surface: AppColors.surface,
      error: AppColors.coral,
      surfaceTint: Colors.transparent, // 떠 있는 요소(드롭다운 등) 틴트 제거
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: colorScheme,
      canvasColor: AppColors.surface, // 드롭다운 펼침 배경을 흰색으로
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.slate,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.notoSansKr(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // 외곽선 버튼의 기본 색은 경고 색(coral)이다. 일반 보조 버튼에는 색을 직접 지정해야 한다.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.coral,
          side: const BorderSide(color: AppColors.coral, width: 1.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              GoogleFonts.notoSansKr(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.slate, width: 1.6),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    );
  }
}
