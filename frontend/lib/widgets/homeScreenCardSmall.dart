import 'dart:math';
import 'package:dashbaord/extensions.dart';
import 'package:dashbaord/widgets/home_screen_mess_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreenCardSmall extends StatelessWidget {
  final String title;
  final dynamic child;
  final bool isLnF;
  final bool isImageShow;
  final bool isComingSoon;
  final void Function() onTap;

  const HomeScreenCardSmall(
      {super.key,
      required this.title,
      this.child,
      this.isLnF = false,
      this.isImageShow = true,
      this.isComingSoon = true,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: context.customColors.customContainerColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(51, 51, 51, 0.10), // Shadow color
                offset: Offset(0, 4), // Offset in the x, y direction
                blurRadius: 10.0,
                spreadRadius: 0.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isImageShow) // Conditional rendering of image
                    SvgPicture.asset(
                      child,
                      fit: BoxFit.contain,
                      height: min(0.32 * screenWidth, 200),
                    ),
                  if (isComingSoon) // Conditional rendering of "coming soon" overlay
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color.fromARGB(255, 57, 57, 57)
                                .withOpacity(0.5)
                            : Colors.white.withOpacity(0.5),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: 100,
                          child: Image.asset("assets/icons/comingsoon.png"),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ));
  }
}
