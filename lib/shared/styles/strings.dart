class AppStrings {
  // ── General ──────────────────────────────────────────────────────────────────
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String confirm = 'Confirm';

  // ── Account names ─────────────────────────────────────────────────────────
  static const String wallet = 'Wallet';
  static const String savings = 'Savings';
  static const String monthlyBudget = 'Monthly Budget';

  // ── Card labels ───────────────────────────────────────────────────────────
  static const String balance = 'Balance';
  static const String remaining = 'Remaining';
  static const String history = 'History';
  static const String bills = 'Bills';

  // ── Home ──────────────────────────────────────────────────────────────────
  static const String goodMorning = '🌅 Good morning,';
  static const String goodAfternoon = '☀️ Good afternoon,';
  static const String goodEvening = '🌙 Good evening,';
  static const String howItWorks = 'How it works';
  static const String addIncomeExpense = 'Add';
  static const String transfer = 'Move';
  static const String newAccount = 'New Account';
  static const String accountName = 'Account name';
  static const String color = 'Color';
  static const String icon = 'Icon';
  static const String createAccount = 'Create Account';

  // ── How it works sheet ────────────────────────────────────────────────────
  static const String howDoesThisWork = 'How does this work?';
  static const String howItWorksSubtitle =
      'A quick overview of your three accounts and wallet logic.';
  static const String sectionYourAccounts = 'YOUR 3 ACCOUNTS';
  static const String sectionSalaryDayLogic = 'SALARY DAY LOGIC';
  static const String walletDescription =
      'Your main spending account. Receives your net salary (Salary − Budget) on each salary day, plus any leftover budget from the previous month.';
  static const String budgetDescription =
      'A dedicated envelope for your monthly expenses. Resets to your preset amount every salary day. Any unspent balance is automatically transferred to your Wallet.';
  static const String savingsDescription =
      'Your long-term savings pot. It is never touched automatically — only you decide when to move money in or out.';
  static const String step1Title = 'Leftover budget is swept';
  static const String step1Body =
      'Any remaining balance in Monthly Budget is moved to your Wallet first.';
  static const String step2Title = 'Net salary is added to Wallet';
  static const String step2Body = 'Wallet  +=  Salary − Monthly Budget';
  static const String step3Title = 'Budget resets';
  static const String step3Body =
      'Monthly Budget is refilled to your preset monthly amount.';

  // ── Tutorial ──────────────────────────────────────────────────────────────
  static const String tutYourAccounts = 'Your Accounts';
  static const String tutYourAccountsBody =
      'Swipe left or right to browse your Wallet, Savings, and Monthly Budget cards.';
  static const String tutAddAccount = 'Add Account';
  static const String tutAddAccountBody =
      'Tap + to create a custom account — give it a name, color, and icon. Perfect for travel funds, side projects, or anything you want to track separately.';
  static const String tutOperations = 'Add';
  static const String tutOperationsBody =
      'Record deposits, withdrawals, or debt on any of your accounts.';
  static const String tutTransfer = 'Move';
  static const String tutTransferBody =
      'Move funds between Wallet, Savings, and Budget instantly.';
  static const String tutNavigation = 'Navigation';
  static const String tutNavigationBody =
      'Use the bottom bar:\n💰 Salary Day — press when your salary arrives\n📊 Analytics — view your spending charts\n👤 Profile — edit your name and budget settings';
  static const String tutBillsTitle = 'Monthly Bills';
  static const String tutBillsBody =
      'Track your fixed monthly expenses here — rent, subscriptions, utilities, and more.';
  static const String tutAddBillTitle = 'Add a Bill';
  static const String tutAddBillBody =
      'Tap + to add a new bill. Each month, mark it as paid and it deducts from your Wallet.';
  static const String tutSwipeTitle = 'Swipe to Manage';
  static const String tutSwipeBody =
      'Swipe a bill right to edit it, or left to delete it.\nTap the ✓ icon to mark it as paid.';

  // ── Profile ───────────────────────────────────────────────────────────────
  static const String profile = 'Profile';
  static const String personalAccount = 'Personal Account';
  static const String sectionPersonalInfo = 'PERSONAL INFO';
  static const String name = 'Name';
  static const String monthlySalary = 'Monthly Salary';
  static const String editName = 'Edit Name';
  static const String editSalary = 'Edit Salary';
  static const String editMonthlyBudget = 'Edit Monthly Budget';
  static const String sectionDangerZone = 'DANGER ZONE';
  static const String resetAppData = 'Reset Current Profile';
  static const String eraseEverythingSubtitle = 'Erase this profile\'s data and start over';
  static const String resetApp = 'Reset Profile';
  static const String resetConfirmBody =
      'This will erase all data for this profile — accounts, transactions, bills, and settings. Other profiles will not be affected.\n\nThis cannot be undone.';
  static const String reset = 'Reset';

  // ── Backup ────────────────────────────────────────────────────────────────
  static const String sectionBackup = 'BACKUP';
  static const String exportBackup = 'Save Backup';
  static const String exportBackupSubtitle = 'Save a copy of this profile\'s data to your device';
  static const String shareBackup = 'Share Backup';
  static const String shareBackupSubtitle = 'Send the backup file to another app';
  static const String restoreBackup = 'Restore Backup';
  static const String restoreBackupSubtitle = 'Replace this profile\'s data from a file';

  // ── Fixed Expenses ────────────────────────────────────────────────────────
  static const String addBillTitle = 'Add Bill';
  static const String editBillTitle = 'Edit Bill';
  static const String billName = 'Bill Name';
  static const String sectionCategory = 'CATEGORY';
  static const String markAsPaid = 'Mark as Paid?';
  static const String noBillsYet = 'No bills yet';
  static const String noBillsSubtitle = 'Tap + to add your first fixed expense';
  static const String deleteBillTitle = 'Delete Bill';
  static const String deleteBillBody = 'Are you sure? This action cannot be undone.';
  static const String insufficientWalletBalance = 'Insufficient wallet balance';
  static const String monthlyBill = 'Monthly Bill';

  // ── Operation ─────────────────────────────────────────────────────────────
  static const String chooseAccount = 'Choose the account';
  static const String chooseAccountSubtitle =
      'Select the account you want to\nperform the operation on:';
  static const String chooseOperation = 'Choose the operation';
  static const String deposit = 'Deposit';
  static const String withdraw = 'Withdraw';
  static const String enterAmount = 'Enter the amount';
  static const String titleOptional = 'Title (optional)';
  static const String noteOptional = 'Note (optional)';
  static const String enterValidAmount = 'Enter a valid amount';
  static const String confirmOperation = 'Confirm';

  // ── Transfer ──────────────────────────────────────────────────────────────
  static const String from = 'From';
  static const String to = 'To';
  static const String amount = 'Amount';
  static const String sectionAccounts = 'ACCOUNTS';
  static const String sectionAmount = 'AMOUNT';
  static const String sectionDetails = 'DETAILS';
  static const String transferFrom = 'Transfer From';
  static const String transferTo = 'Transfer To';
  static const String confirmTransfer = 'Confirm Transfer';

  // ── History ───────────────────────────────────────────────────────────────
  static const String noTransactions = 'No transactions yet';
  static const String historyEmptySubtitle = 'Your history will appear here.';
  static const String deletedAccount = 'Deleted Account';

  // ── Multi-profile ─────────────────────────────────────────────────────────
  static const String switchProfile = 'Switch Profile';
  static const String switchProfileSubtitle = 'Switch between your profiles';

  // ── Custom Account Detail ─────────────────────────────────────────────────
  static const String accountDetails = 'Account Details';
  static const String sectionAccountName = 'ACCOUNT NAME';
  static const String sectionColor = 'COLOR';
  static const String sectionIcon = 'ICON';
  static const String saveChanges = 'Save Changes';
  static const String deleteAccount = 'Delete Account';
  static const String removeAccountSubtitle = 'Remove this account permanently';
  static const String transferToWallet = 'Transfer to Wallet';
  static const String discardBalance = 'Discard balance';

  // ── Onboarding ────────────────────────────────────────────────────────────
  static const String onboardingTitle = 'Money made\nsimple.';
  static const String onboardingSubtitle =
      'Know where your money goes.\nStay on budget. Grow your savings.';
  static const String onboardingBullet1 = 'Track every penny in and out';
  static const String onboardingBullet2 = 'Separate your budget from your wallet';
  static const String onboardingBullet3 = 'Watch your savings grow over time';
  static const String nameStepTitle = "What's your\nname?";
  static const String nameStepSubtitle =
      'This will appear in your wallet greeting.';
  static const String currencyStepTitle = 'Pick your\ncurrency.';
  static const String currencyStepSubtitle =
      'All amounts will be displayed in your\nselected currency.';
  static const String salaryStepTitle = 'Monthly\nSalary?';
  static const String salaryStepSubtitle =
      'How much do you earn per month?\nThis is used on salary day.';
  static const String budgetStepTitle = 'Monthly\nBudget?';
  static const String budgetStepSubtitle =
      'How much do you allocate for\nmonthly expenses?';
  static const String savingsStepTitle = 'Current\nSavings?';
  static const String savingsStepSubtitle =
      'How much do you already have saved?\n(Enter 0 if starting fresh)';
  static const String yourNameHint = 'Your name';
  static const String searchCurrencies = 'Search currencies...';
  static const String noResults = 'No results';
  static const String letsBegin = "Let's Begin";
  static const String continueBtn = 'Continue';
  static const String getStarted = 'Get Started';

  // ── Months ────────────────────────────────────────────────────────────────
  static const List<String> monthsFull = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> monthsShort = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
