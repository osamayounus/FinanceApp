# Smart Wallet App
> Smart Wallet is a comprehensive personal finance management application designed to simplify how users track their income, expenses, and savings. Built around an intelligent automation system, the app minimizes manual entry and offers a seamless, "one-click" approach to managing monthly salary cycles and account compartmentalization.
---

## ✨ Key Features

### 🤖 Smart Automation: The "Receive Salary" Logic
The core of Smart Wallet is its intelligent salary processing. With a single tap, the app dynamically updates your entire financial ecosystem:
* **Calculates Net Funds:** Moves `(Salary - Expenses)` directly into your main **Wallet**.
* **Smart Rollover:** Automatically transfers any unspent funds from the previous month's Expense account into the Wallet.
* **Reset Budget:** Resets the **Expense** account back to its predefined monthly limit.
* **Reactivate Bills:** Automatically resets and reactivates all recurring monthly bills.

### 🏦 Dynamic Account Compartments
* **Wallet:** The primary balance holding the remaining funds after monthly expenses.
* **Expenses:** A dedicated account holding the strict monthly budget for day-to-day spending.
* **Savings:** Secure allocation for long-term financial goals.
* **Custom Accounts:** Fully personalized accounts (configurable with custom names, colors, and icons).

### 📊 Comprehensive Analytics Dashboard
A highly responsive, scrollable 6-month financial dashboard designed to give users immediate insights into their financial health:
* **🧠 Smart Insights Card:** Auto-generated, rule-based observations (spending trends, budget usage, savings activity, bills status, best/worst month).
* **📅 Monthly Snapshot Card:** A dark-gradient card displaying current month income, spending, and a dynamic color-coded budget progress bar.
* **📉 Spending Chart Card:** Grouped bar chart comparing *Income vs. Spent* over the last 6 months.
* **🍩 Category Chart Card:** Interactive donut chart breaking down fixed bills by category. Tapping a slice highlights the category and displays its percentage share.
* **📈 Savings Chart Card:** Line chart visualizing the Savings account balance (past months are represented by end-of-month data points, while the current month expands to plot every individual transaction).

### 💸 Financial Operations & Tracking
* **Flexible Transactions:** Transfer funds between any accounts, deposit, or withdraw.
* **Bill Management:** Add and track fixed monthly bills directly within the Wallet.
* **Detailed History:** Comprehensive logs for all transactions across every account.
* **Account Management:** Create, delete, and migrate funds from custom accounts safely.
* **Factory Reset:** A global reset button to wipe all data and start completely fresh.

---

## 🛠️ Technical Architecture & State Management

The analytics dashboard is built for high performance and reactivity:

* **Central Analytics Flow:** All analytics data flows through a central `analyticsProvider` (`FutureProvider`). This provider re-evaluates and runs upon every transaction by watching the `accountsProvider`.
* **Asynchronous Optimization:** To ensure UI fluidity, bills and budget balances utilize independent providers. This architecture allows them to update instantly without waiting for heavier async analytics computations.

