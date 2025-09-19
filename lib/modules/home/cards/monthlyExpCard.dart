import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/cubit/cubit.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MonthlyExpCard extends StatelessWidget {
  const MonthlyExpCard({super.key});

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
              color: Colors.red,
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
                        'Monthly Expenses',
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontFamily: 'Rubik',
                          color: AppColors.secondary,
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
                        '80',
                        style: TextStyle(
                          fontSize: screenWidth * 0.15,
                          fontFamily: 'Rubik',
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'JOD',
                        style: TextStyle(
                          fontSize: screenWidth * 0.050,
                          fontFamily: 'Rubik',
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.020),
                  Row(
                    children: [
                      Expanded(
                        child: LightButton(
                          width: double.infinity,
                          text: 'History',
                          textColor: Colors.red,
                          onPressed: () {AppCubit.get(context).openHistoryPage('Monthly expenses',context);},
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
