import 'package:financeapp/shared/styles/colors.dart';
import 'package:flutter/material.dart';

class Profilepage extends StatelessWidget {
  const Profilepage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 100,
            horizontal: 30
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(fontFamily: 'Rubik', color: AppColors.secondary,fontSize: 30),
              ),
              const SizedBox(height: 50),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInfoRow(
                    icon: Icons.person_rounded,
                    label: 'Name',
                    value: 'Osama',
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    icon: Icons.monetization_on_rounded,
                    label: 'Income (monthly)',
                    value: '555 JOD',
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Expenses (monthly)',
                    value: '80 JOD',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Reset',
                style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 17)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          child: Row(
            children: [
              Icon(
                icon,
                size: 50,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ],
          ),
        ),
        Divider(
          thickness: 1,
          color: Colors.white,
        ),
      ],
    );
  }
}
