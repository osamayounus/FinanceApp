import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class Salarydaypage extends StatelessWidget {
  const Salarydaypage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.primary,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Press here if and only if',
                  style: TextStyle(fontFamily: 'Rubik', color: AppColors.secondary,fontSize: 20),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'نزل الراتب',
                  style: TextStyle(fontFamily: 'Rubik', color: AppColors.secondary,fontSize: 20),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'lib/shared/styles/images/coin.svg',
                  width: 300,
                  height: 300,
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Your balance will be updated automatically',
                    style: TextStyle(fontFamily: 'Rubik', color: Colors.white54,fontSize: 20),
                    textAlign: TextAlign.center,

                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
