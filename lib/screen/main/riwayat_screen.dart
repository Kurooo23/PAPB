import 'package:flutter/material.dart';

class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = size.width * 0.04;

    return Column(
      children: [
        const Spacer(flex: 4),

        Icon(Icons.history, size: size.width * 0.14, color: Colors.white),
        SizedBox(height: size.height * 0.015),
        const Text('Belum ada riwayat',
          style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: size.height * 0.008),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const[
              Icon(Icons.info_outline, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Flexible(child: Text('Turnamen yang selesai akan muncul disini', style: TextStyle(fontSize: 12, color: Colors.white70),),
              ),
            ],
          ),
        ),
        const Spacer(flex: 5),
      ],
    );
  }
}