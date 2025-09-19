import 'package:card_swiper/card_swiper.dart';
import 'package:financeapp/modules/home/cards/incomeCard.dart';
import 'package:financeapp/modules/home/cards/monthlyExpCard.dart';
import 'package:financeapp/modules/home/cards/savingCard.dart';
import 'package:financeapp/shared/components/components.dart';
import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';

class Homepage extends StatelessWidget {
  final List<Widget> cards = [
    IncomeCard(),
    SavingCard(),
    MonthlyExpCard()
  ];
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        color: AppColors.primary,
        child: Column(
          spacing: screenHeight*0.1,
          children: [
            Container(
              margin: EdgeInsets.only(
                top: screenHeight*0.15
              ),
              width: screenWidth*0.8,
              child: Text(
                'Welcome back, Username!',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontFamily: 'Rubik',
                  fontSize: 20,
                ),
              ),
            ),
            Swiper(
              itemBuilder: (BuildContext context, int index) {
                return cards[index];
              },
              itemCount: cards.length,
              itemWidth: screenWidth* 0.8,
              itemHeight: screenHeight*0.28,
              layout: SwiperLayout.STACK,
              axisDirection: AxisDirection.right,
            ),
            Column( spacing: 20,
              children: [
                LightButton(
                    width: screenWidth*0.8,
                    text: 'Add Income/Expense',
                    textColor: AppColors.primary,
                    onPressed: () {
                      print('hi there!!!!!!!!!!!');
                    }),
                LightButton(
                    width: screenWidth*0.8,
                    text: 'Transfer',
                    textColor: AppColors.primary,
                    onPressed: () {
                      print('hi there!!!!!!!!!!!2');
                    }),
              ],
            ),
          ],
        )
      ),
    );
  }
}
