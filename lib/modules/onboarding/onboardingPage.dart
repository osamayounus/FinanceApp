import 'package:financeapp/main.dart';
import 'package:financeapp/models/user_model.dart';
import 'package:financeapp/providers/app_provider.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:financeapp/shared/styles/sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0;
  bool _loading = false;
  String? _errorMessage;

  final _nameCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _savingsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _salaryCtrl.dispose();
    _budgetCtrl.dispose();
    _savingsCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _nameCtrl.text.trim();
    final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
    final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0;
    final savings = double.tryParse(_savingsCtrl.text.trim()) ?? 0;

    if (name.isEmpty || salary <= 0 || budget <= 0) return;

    setState(() => _loading = true);

    final db = ref.read(dbProvider);
    final user = UserModel(id: 1, name: name, salary: salary, monthlyBudget: budget);
    await db.insertUser(user);
    await db.initAccounts(
      initialSavings: savings,
      salary: salary,
      monthlyBudget: budget,
    );

    final accounts = await db.getAccounts();
    final bills = await db.getBills();

    // Update global config — AppRoot rebuilds ProviderScope with real data.
    // No nested navigation needed; the MaterialApp's home switches automatically.
    appConfigNotifier.value = AppConfig(
      isSetup: true,
      isFirstRun: true,
      db: db,
      user: user,
      accounts: accounts,
      bills: bills,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSizes.xl, vertical: AppSizes.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button ──────────────────────────────────────────
              if (_step > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    _step--;
                    _errorMessage = null;
                  }),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                )
              else
                SizedBox(height: AppSizes.xl),

              SizedBox(height: AppSizes.xl),

              // ── Header ──────────────────────────────────────────────
              Text(
                _stepTitle,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: AppSizes.s),
              Text(
                _stepSubtitle,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: AppSizes.fontS,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),

              SizedBox(height: AppSizes.xxl),

              // ── Input ────────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildField(),
                ),
              ),

              if (_errorMessage != null) ...[
                SizedBox(height: AppSizes.s),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 16),
                    SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontFamily: 'Rubik',
                          fontSize: 13,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const Spacer(),

              // ── Step dots ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _step ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _step
                          ? AppColors.myGreen
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              SizedBox(height: AppSizes.l),

              // ── Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: AppSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.myGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusXL)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Text(
                          _step == 0 ? "Let's Begin" : _step < 4 ? 'Continue' : 'Get Started',
                          style: TextStyle(
                            fontFamily: 'Rubik',
                            fontSize: AppSizes.fontM,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onNext() {
    if (_step < 4) {
      if (!_validateCurrent()) return;
      setState(() {
        _step++;
        _errorMessage = null;
      });
    } else {
      if (!_validateCurrent()) return;
      _finish();
    }
  }

  bool _validateCurrent() {
    switch (_step) {
      case 0:
        return true; // intro — no input required
      case 1:
        if (_nameCtrl.text.trim().isEmpty) return false;
        return true;
      case 2:
        if ((double.tryParse(_salaryCtrl.text.trim()) ?? 0) <= 0) return false;
        return true;
      case 3:
        final budget = double.tryParse(_budgetCtrl.text.trim()) ?? 0;
        final salary = double.tryParse(_salaryCtrl.text.trim()) ?? 0;
        if (budget <= 0) return false;
        if (budget >= salary) {
          setState(() => _errorMessage =
              'Budget must be less than your salary (${salary.toInt()} JOD)');
          return false;
        }
        setState(() => _errorMessage = null);
        return true;
      default:
        return true; // savings optional
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 0:
        return "Money made\nsimple.";
      case 1:
        return "What's your\nname?";
      case 2:
        return "Monthly\nSalary?";
      case 3:
        return "Monthly\nBudget?";
      case 4:
        return "Current\nSavings?";
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0:
        return "Know where your money goes.\nStay on budget. Grow your savings.";
      case 1:
        return "This will appear in your wallet greeting.";
      case 2:
        return "How much do you earn per month?\nThis is used on salary day.";
      case 3:
        return "How much do you allocate for\nmonthly expenses?";
      case 4:
        return "How much do you already have saved?\n(Enter 0 if starting fresh)";
      default:
        return '';
    }
  }

  Widget _buildField() {
    switch (_step) {
      case 0:
        return _buildIntro();
      case 1:
        return _inputCard(
          controller: _nameCtrl,
          hint: 'Your name',
          suffix: null,
          isNumber: false,
        );
      case 2:
        return _inputCard(
          controller: _salaryCtrl,
          hint: '0',
          suffix: 'JOD',
          isNumber: true,
        );
      case 3:
        return _inputCard(
          controller: _budgetCtrl,
          hint: '0',
          suffix: 'JOD',
          isNumber: true,
        );
      case 4:
        return _inputCard(
          controller: _savingsCtrl,
          hint: '0',
          suffix: 'JOD',
          isNumber: true,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _introBullet(Icons.track_changes_rounded, 'Track every penny in and out'),
        SizedBox(height: AppSizes.m),
        _introBullet(Icons.pie_chart_rounded, 'Separate your budget from your wallet'),
        SizedBox(height: AppSizes.m),
        _introBullet(Icons.trending_up_rounded, 'Watch your savings grow over time'),
      ],
    );
  }

  Widget _introBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.myGreen, size: AppSizes.iconM),
        SizedBox(width: AppSizes.m),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Rubik',
              fontSize: AppSizes.fontM,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputCard({
    required TextEditingController controller,
    required String hint,
    required String? suffix,
    required bool isNumber,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.12), width: 1.5),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.name,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        style: const TextStyle(
          fontFamily: 'Rubik',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Rubik',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          suffixText: suffix,
          suffixStyle: TextStyle(
            fontFamily: 'Rubik',
            fontSize: AppSizes.fontL,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSizes.l,
            vertical: AppSizes.l,
          ),
        ),
      ),
    );
  }
}
