import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/cubit/cubit.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SavingCard extends StatelessWidget {
  const SavingCard({super.key});

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
              color: Colors.green,
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
                        'Saving',
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
                        '1000',
                        style: TextStyle(
                          fontSize: screenWidth * 0.15,
                          fontFamily: 'Rubik',
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.015),
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
                          textColor: Colors.green,
                          onPressed: () {AppCubit.get(context).openHistoryPage('Saving',context);},
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
