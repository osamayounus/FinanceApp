import 'package:bloc/bloc.dart';
import 'package:financeapp/modules/fixedExp/FixedExpensesPage.dart';
import 'package:financeapp/modules/history/historyPage.dart';
import 'package:financeapp/modules/home/homePage.dart';
import 'package:financeapp/modules/profile/profilePage.dart';
import 'package:financeapp/modules/salaryDay/salaryDayPage.dart';
import 'package:financeapp/shared/cubit/states.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppCubit extends Cubit<AppStates>{
  AppCubit(): super(appInitState());
  static AppCubit get(context) => BlocProvider.of(context);
  List<Widget> mainPages = [
    Salarydaypage(),
    Homepage(),
    Profilepage()
  ];
  int selectedPageIndex = 0;
  
  void changeMainPage(int index){
    selectedPageIndex = index;
    emit(changeMainPageState());
  }

  void openHistoryPage(String pageName,context){
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Historypage(pageName)),
    );
    emit(changePageState());
  }

  void openFixedExpensesPage(context){
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Fixedexpensespage()),
    );
    emit(changePageState());
  }

  void changeBackPage(context){
    Navigator.pop(
      context,
    );
    emit(changePageState());
  }

  void addExpense(String name, int amount) {
    // final updatedList = List<Map<String, dynamic>>.from(state.expenses)
    //   ..add({"name": name, "amount": amount});
    // emit(FixedExpensesState(expenses: updatedList));
  }

  void editExpense(int index, String newName, int newAmount) {
    // final updatedList = List<Map<String, dynamic>>.from(state.expenses);
    // updatedList[index] = {"name": newName, "amount": newAmount};
    // emit(FixedExpensesState(expenses: updatedList));
  }

  void deleteExpense(int index) {
    // final updatedList = List<Map<String, dynamic>>.from(state.expenses)
    //   ..removeAt(index);
    // emit(FixedExpensesState(expenses: updatedList));
  }

}