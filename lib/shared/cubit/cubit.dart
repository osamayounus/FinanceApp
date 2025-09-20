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

  // TODO: Move to DB
  List<Map<String, dynamic>> expenses = [
    {"name": "My Family", "amount": 100, "state":false},
    {"name": "I phone", "amount": 44, "state":false},
  ];
  
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
    expenses.add({"name": name, "amount": amount, "state":false});
     emit(FixedExpensesState());
  }

  void editExpense(int index, String newName, int newAmount) {
    expenses[index]["name"] = newName;
    expenses[index]["amount"] = newAmount;
    emit(FixedExpensesState());
  }

  void deleteExpense(int index) {
    expenses.removeAt(index);
    emit(FixedExpensesState());
  }

  void doneExpense(int index) {
    expenses[index]["state"] = true;
    emit(FixedExpensesState());
  }

}