import 'package:flutter/material.dart';

class Fixedexpensespage extends StatelessWidget {
  List<Map<String, dynamic>> expenses = [
    {"name": "My Family", "amount": 100},
    {"name": "I phone", "amount": 44},
    {"name": "Fd", "amount": 20},
  ];

  TextEditingController nameController = TextEditingController();
  TextEditingController amountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xfff8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Fixed Expenses", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final item = expenses[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xff0b0c2a),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item["name"],
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  Text(
                    "${item["amount"]} JOD",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      // زر فاضي مبدئيًا
                    },
                    icon: Icon(Icons.checklist, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.edit, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.delete, color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xff0b0c2a),
        onPressed: (){},
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
