import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/cubit/cubit.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Historypage extends StatelessWidget {
  Historypage(this.pageName);
  String pageName;

  final List<Map<String, dynamic>> transactions = [
    {
      'type': 'Withdraw',
      'amount': 5.0,
      'description': 'I bought a Book',
      'dateTime': DateTime(2025, 5, 27, 17, 30),
    },
    {
      'type': 'Deposit',
      'amount': 20.0,
      'description': 'Sold Old Laptop',
      'dateTime': DateTime(2025, 5, 26, 10, 15),
    },
    {
      'type': 'Transfer',
      'amount': 10.0,
      'description': 'To Saving Account',
      'dateTime': DateTime(2025, 5, 25, 15, 45),
    },
    {
      'type': 'Withdraw',
      'amount': 7.5,
      'description': 'Dinner at Restaurant',
      'dateTime': DateTime(2025, 5, 24, 20, 0),
    },
    {
      'type': 'Deposit',
      'amount': 100.0,
      'description': 'Salary Payment',
      'dateTime': DateTime(2025, 5, 24, 9, 0),
    },
    {
      'type': 'Withdraw',
      'amount': 15.0,
      'description': 'Bought Groceries',
      'dateTime': DateTime(2025, 5, 23, 18, 30),
    },
    {
      'type': 'Deposit',
      'amount': 30.0,
      'description': 'Returned Item Refund',
      'dateTime': DateTime(2025, 5, 22, 12, 45),
    },
    {
      'type': 'Transfer',
      'amount': 8.0,
      'description': 'To Investment Account',
      'dateTime': DateTime(2025, 5, 21, 14, 20),
    },
    {
      'type': 'Withdraw',
      'amount': 3.0,
      'description': 'Coffee with friends',
      'dateTime': DateTime(2025, 5, 20, 19, 10),
    },
    {
      'type': 'Deposit',
      'amount': 60.0,
      'description': 'Freelance Project',
      'dateTime': DateTime(2025, 5, 19, 13, 50),
    },
    {
      'type': 'Withdraw',
      'amount': 12.0,
      'description': 'Cinema Ticket',
      'dateTime': DateTime(2025, 5, 18, 21, 15),
    },
    {
      'type': 'Transfer',
      'amount': 25.0,
      'description': 'To Family Support',
      'dateTime': DateTime(2025, 5, 17, 11, 30),
    },
  ];


  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) => AppCubit(),
        child: BlocConsumer<AppCubit,AppStates>(
          listener: (BuildContext context, Object? state) {},
          builder: (context, state) => Scaffold(
              body: Container(
                color: AppColors.secondary,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,70,10,15
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              AppCubit.get(context).changeBackPage(context);
                            },
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.black,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$pageName History',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Rubik',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          SizedBox(width: 48),
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            return TransactionCard(
                              type: tx['type'],
                              amount: tx['amount'],
                              description: tx['description'],
                              dateTime: tx['dateTime'],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        )
    );
  }
}
