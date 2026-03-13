
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/cupertino.dart';
import 'package:untitled/features/UI/screen/PurchaseScreen.dart';
import 'home_screen.dart';




class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _goToNextPage();
  }

  Future<void> _goToNextPage() async {
    // Show splash for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    // Navigate to HomeScreen using standard Flutter navigation
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PurchaseScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child:  Center(
          child: SizedBox(
            width: 305.w,
            height: 305.h,
            child: Applogo(),
          ),
        ),
      ),
    );
  }
}



class Applogo extends StatelessWidget {
  const Applogo({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/Volumix-png.png',
      height: height ?? 120.h,
      width: width ?? 120.w,
      fit: BoxFit.contain,
    );
  }
}