import 'package:financeapp/shared/cubit/cubit.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../shared/styles/colors.dart';

class Walletlayoutpage extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    double navPaddingHor = MediaQuery.of(context).size.width * 0.10;
    double navPaddingVer = MediaQuery.of(context).size.height * 0.03;
    return BlocProvider
      (
        create: (context) => AppCubit(),
        child: BlocConsumer<AppCubit,AppStates>(
            builder: (context, state) => Scaffold(
              body: AppCubit.get(context).mainPages[AppCubit.get(context).selectedPageIndex],
              bottomNavigationBar: Container(
                color: AppColors.primary,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: navPaddingHor,
                      vertical: navPaddingVer
                  ),
                  child: GNav(
                      gap: 8,
                      padding: EdgeInsets.all(8),
                      backgroundColor: AppColors.primary,
                      tabBackgroundColor: AppColors.secondary,
                      selectedIndex: AppCubit.get(context).selectedPageIndex,
                      onTabChange: (index){
                        AppCubit.get(context).changeMainPage(index);
                      },
                      color: AppColors.secondary,
                      activeColor: AppColors.primary,
                      textStyle: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w500),
                      tabs: [
                        GButton(
                          icon: Icons.attach_money_rounded,
                          text: 'Salary Day',
                          iconSize: 32,
                        ),
                        GButton(
                          icon: Icons.wallet_outlined,
                          text: 'Wallet',
                          iconSize: 32,
                        ),
                        GButton(
                          icon: Icons.account_circle_rounded,
                          text: 'Profile',
                          iconSize: 32,
                        )
                      ]
                  ),
                ),
              ),
            ),
            listener: (BuildContext context, Object? state) {},
        ),
      );
  }
}
