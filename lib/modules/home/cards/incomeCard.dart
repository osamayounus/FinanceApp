import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/cubit/cubit.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IncomeCard extends StatelessWidget {
  const IncomeCard({super.key});
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return BlocProvider(
      create: (context) => AppCubit(),
        child: BlocConsumer<AppCubit,AppStates>(
            builder: (context, state) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.03),
                color: AppColors.secondary,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.015,
                  horizontal: screenWidth * 0.04,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Income',
                          style: TextStyle(
                            fontSize: screenWidth * 0.07,
                            fontFamily: 'Rubik',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '555',
                          style: TextStyle(
                            fontSize: screenWidth * 0.15,
                            fontFamily: 'Rubik',
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.015),
                        Text(
                          'JOD',
                          style: TextStyle(
                            fontSize: screenWidth * 0.050,
                            fontFamily: 'Rubik',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: screenHeight * 0.020),
                    Row(
                      children: [
                        Expanded(
                          child: DarkButton(
                            width: double.infinity,
                            text: 'History',
                            onPressed: () {
                              AppCubit.get(context).openHistoryPage('Income',context);
                            },
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.015),
                        Expanded(
                          child: DarkButton(
                            width: double.infinity,
                            text: 'Bills',
                            onPressed: () {
                              AppCubit.get(context).openFixedExpensesPage(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            listener: (BuildContext context, Object? state) {},
        )
    );
  }
}
