import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF36393F);
  static const Color cardBackground = Color(0xFF2F3136);
  static const Color accentBlurple = Color(0xFF7289DA);
  static const Color secondaryText = Color.fromARGB(255, 100, 100, 100);
  
  static Color? lightGrey700 = Colors.grey[700];
  static Color? lightGrey800 = Colors.grey[800];
  static Color? lightGrey400 = Colors.grey[400];
  static Color? lightGrey300 = Colors.grey[300];
  static Color? lightGrey500 = Colors.grey[500];
}

class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 20.0;
  
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusCircle = 35.0;
  
  static const double serverRailWidth = 70.0;
  static const double channelListWidth = 240.0;
  static const double avatarRadiusSmall = 24.0;
  static const double avatarRadiusLarge = 40.0;
}

class AppText {
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle textRegular = TextStyle(
    fontSize: 14,
    color: Colors.white,
  );

  static const TextStyle textSmall = TextStyle(
    fontSize: 12,
    color: Colors.white,
  );
}

class AppConstants {
  static const List<String> mockGifUrls = [
    'https://media.giphy.com/media/l0HlNaQ9WLVf0XO1i/giphy.gif',
    'https://media.giphy.com/media/13HgknN6E5Oavq/giphy.gif',
    'https://media.giphy.com/media/3o7TKU6bNES76bz0A0/giphy.gif',
  ];

  static const List<String> mockImageUrls = [
    'https://images.unsplash.com/photo-1611162617305-c69b3fa7fbe0?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=400&h=300&fit=crop',
    'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&h=300&fit=crop',
  ];
}
